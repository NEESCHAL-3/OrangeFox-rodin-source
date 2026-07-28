#include <aidl/android/hardware/secure_element/BnSecureElementCallback.h>
#include <aidl/android/hardware/secure_element/ISecureElement.h>
#include <aidl/android/hardware/secure_element/LogicalChannelResponse.h>
#include <aidl/android/se/omapi/BnSecureElementChannel.h>
#include <aidl/android/se/omapi/BnSecureElementReader.h>
#include <aidl/android/se/omapi/BnSecureElementService.h>
#include <aidl/android/se/omapi/BnSecureElementSession.h>
#include <aidl/android/se/omapi/ISecureElementListener.h>
#include <android-base/logging.h>
#include <android-base/properties.h>
#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <algorithm>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

namespace {

namespace hwse = aidl::android::hardware::secure_element;
namespace omapi = aidl::android::se::omapi;

constexpr char kSecureElementInstance[] =
        "android.hardware.secure_element.ISecureElement/eSE1";
constexpr char kOmapiInstance[] =
        "android.se.omapi.ISecureElementService/default";
constexpr char kReaderName[] = "eSE1";

ndk::ScopedAStatus IllegalArgument(const char* message) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_ILLEGAL_ARGUMENT, message);
}

ndk::ScopedAStatus IllegalState(const char* message) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_ILLEGAL_STATE, message);
}

ndk::ScopedAStatus NullPointer(const char* message) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_NULL_POINTER, message);
}

ndk::ScopedAStatus Unsupported(const char* message) {
    return ndk::ScopedAStatus::fromExceptionCodeWithMessage(EX_UNSUPPORTED_OPERATION, message);
}

ndk::ScopedAStatus ForwardHalError(const char* operation,
                                   const ndk::ScopedAStatus& status) {
    const char* raw_message = status.getMessage();
    const std::string message = raw_message != nullptr ? raw_message : operation;
    LOG(ERROR) << operation << " failed: exception=" << status.getExceptionCode()
               << " service_error=" << status.getServiceSpecificError()
               << " message=" << message;
    const int32_t error = status.getExceptionCode() == EX_SERVICE_SPECIFIC
            ? status.getServiceSpecificError()
            : hwse::ISecureElement::FAILED;
    return ndk::ScopedAStatus::fromServiceSpecificErrorWithMessage(error, message.c_str());
}

bool IsValidAid(const std::vector<uint8_t>& aid) {
    return aid.empty() || (aid.size() >= 5 && aid.size() <= 16);
}

bool IsValidP2(int8_t p2) {
    const uint8_t value = static_cast<uint8_t>(p2);
    return value == 0x00 || value == 0x04 || value == 0x08 || value == 0x0c;
}

class SecureElementCallback final : public hwse::BnSecureElementCallback {
  public:
    ndk::ScopedAStatus onStateChange(bool connected,
                                     const std::string& debug_reason) override {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            connected_ = connected;
            reason_ = debug_reason;
        }
        condition_.notify_all();
        LOG(INFO) << "Secure Element state changed: connected=" << connected
                  << " reason=" << debug_reason;
        return ndk::ScopedAStatus::ok();
    }

    bool WaitUntilConnected(std::chrono::seconds timeout) {
        std::unique_lock<std::mutex> lock(mutex_);
        condition_.wait_for(lock, timeout, [this] { return connected_; });
        if (!connected_) {
            LOG(ERROR) << "Secure Element did not become ready: " << reason_;
            return false;
        }
        return true;
    }

  private:
    std::mutex mutex_;
    std::condition_variable condition_;
    bool connected_ = false;
    std::string reason_;
};

class SecureElementBackend final {
  public:
    bool Connect() {
        ndk::SpAIBinder binder(AServiceManager_waitForService(kSecureElementInstance));
        secure_element_ = hwse::ISecureElement::fromBinder(binder);
        if (secure_element_ == nullptr) {
            LOG(ERROR) << "Unable to obtain " << kSecureElementInstance;
            return false;
        }

        callback_ = ndk::SharedRefBase::make<SecureElementCallback>();
        const ndk::ScopedAStatus status = secure_element_->init(callback_);
        if (!status.isOk()) {
            ForwardHalError("ISecureElement::init", status);
            return false;
        }
        return callback_->WaitUntilConnected(std::chrono::seconds(10));
    }

    ndk::ScopedAStatus IsCardPresent(bool* present) {
        std::lock_guard<std::mutex> lock(io_mutex_);
        const ndk::ScopedAStatus status = secure_element_->isCardPresent(present);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : ForwardHalError("ISecureElement::isCardPresent", status);
    }

    ndk::ScopedAStatus GetAtr(std::vector<uint8_t>* atr) {
        std::lock_guard<std::mutex> lock(io_mutex_);
        const ndk::ScopedAStatus status = secure_element_->getAtr(atr);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : ForwardHalError("ISecureElement::getAtr", status);
    }

    ndk::ScopedAStatus OpenBasicChannel(const std::vector<uint8_t>& aid, int8_t p2,
                                        std::vector<uint8_t>* response) {
        std::lock_guard<std::mutex> lock(io_mutex_);
        const ndk::ScopedAStatus status =
                secure_element_->openBasicChannel(aid, p2, response);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : ForwardHalError("ISecureElement::openBasicChannel", status);
    }

    ndk::ScopedAStatus OpenLogicalChannel(const std::vector<uint8_t>& aid, int8_t p2,
                                          hwse::LogicalChannelResponse* response) {
        std::lock_guard<std::mutex> lock(io_mutex_);
        const ndk::ScopedAStatus status =
                secure_element_->openLogicalChannel(aid, p2, response);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : ForwardHalError("ISecureElement::openLogicalChannel", status);
    }

    ndk::ScopedAStatus CloseChannel(int8_t channel_number) {
        std::lock_guard<std::mutex> lock(io_mutex_);
        const ndk::ScopedAStatus status = secure_element_->closeChannel(channel_number);
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : ForwardHalError("ISecureElement::closeChannel", status);
    }

    ndk::ScopedAStatus Reset() {
        std::lock_guard<std::mutex> lock(io_mutex_);
        const ndk::ScopedAStatus status = secure_element_->reset();
        return status.isOk() ? ndk::ScopedAStatus::ok()
                             : ForwardHalError("ISecureElement::reset", status);
    }

    ndk::ScopedAStatus Transmit(std::vector<uint8_t> command,
                                std::vector<uint8_t>* response) {
        std::lock_guard<std::mutex> lock(io_mutex_);
        return TransmitLocked(std::move(command), response);
    }

  private:
    ndk::ScopedAStatus TransmitOnceLocked(const std::vector<uint8_t>& command,
                                          std::vector<uint8_t>* response) {
        const ndk::ScopedAStatus status = secure_element_->transmit(command, response);
        if (!status.isOk()) {
            return ForwardHalError("ISecureElement::transmit", status);
        }
        if (response->size() < 2) {
            return ndk::ScopedAStatus::fromServiceSpecificErrorWithMessage(
                    hwse::ISecureElement::IOERROR, "APDU response is shorter than a status word");
        }
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus TransmitLocked(std::vector<uint8_t> command,
                                      std::vector<uint8_t>* response) {
        ndk::ScopedAStatus status = TransmitOnceLocked(command, response);
        if (!status.isOk()) {
            return status;
        }

        if ((*response)[response->size() - 2] == 0x6c && command.size() >= 5) {
            command.back() = response->back();
            status = TransmitOnceLocked(command, response);
            if (!status.isOk()) {
                return status;
            }
        }

        std::vector<uint8_t> accumulated;
        for (size_t attempt = 0;
             attempt < 32 && (*response)[response->size() - 2] == 0x61; ++attempt) {
            accumulated.insert(accumulated.end(), response->begin(), response->end() - 2);
            const uint8_t expected_length = response->back();
            std::vector<uint8_t> get_response = {
                    command[0], 0xc0, 0x00, 0x00, expected_length};
            status = TransmitOnceLocked(get_response, response);
            if (!status.isOk()) {
                return status;
            }
        }
        if (!accumulated.empty()) {
            accumulated.insert(accumulated.end(), response->begin(), response->end());
            *response = std::move(accumulated);
        }
        return ndk::ScopedAStatus::ok();
    }

    std::shared_ptr<hwse::ISecureElement> secure_element_;
    std::shared_ptr<SecureElementCallback> callback_;
    std::mutex io_mutex_;
};

class OmapiChannel final : public omapi::BnSecureElementChannel {
  public:
    OmapiChannel(std::shared_ptr<SecureElementBackend> backend, int8_t channel_number,
                 std::vector<uint8_t> select_response, std::vector<uint8_t> aid,
                 std::shared_ptr<omapi::ISecureElementListener> listener)
        : backend_(std::move(backend)),
          channel_number_(channel_number),
          select_response_(std::move(select_response)),
          aid_(std::move(aid)),
          listener_(std::move(listener)) {}

    ndk::ScopedAStatus close() override {
        std::lock_guard<std::mutex> lock(mutex_);
        if (closed_) {
            return ndk::ScopedAStatus::ok();
        }
        if (channel_number_ == 0) {
            std::vector<uint8_t> ignored;
            (void)backend_->Transmit({0x00, 0xa4, 0x04, 0x00, 0x00}, &ignored);
        }
        ndk::ScopedAStatus status = backend_->CloseChannel(channel_number_);
        closed_ = true;
        listener_.reset();
        if (channel_number_ == 0) {
            return ndk::ScopedAStatus::ok();
        }
        return status;
    }

    ndk::ScopedAStatus isClosed(bool* closed) override {
        std::lock_guard<std::mutex> lock(mutex_);
        *closed = closed_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus isBasicChannel(bool* basic) override {
        *basic = channel_number_ == 0;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus getSelectResponse(std::vector<uint8_t>* response) override {
        std::lock_guard<std::mutex> lock(mutex_);
        if (closed_) {
            return IllegalState("Channel is closed");
        }
        *response = select_response_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus transmit(const std::vector<uint8_t>& command,
                                std::vector<uint8_t>* response) override {
        std::lock_guard<std::mutex> lock(mutex_);
        if (closed_) {
            return IllegalState("Channel is closed");
        }
        if (command.size() < 4) {
            return IllegalArgument("APDU command is too short");
        }
        std::vector<uint8_t> routed_command = command;
        ndk::ScopedAStatus status =
                SetChannelToClassByte(&routed_command[0], channel_number_);
        if (!status.isOk()) {
            return status;
        }
        return backend_->Transmit(std::move(routed_command), response);
    }

    ndk::ScopedAStatus selectNext(bool* selected) override {
        std::lock_guard<std::mutex> lock(mutex_);
        if (closed_) {
            return IllegalState("Channel is closed");
        }
        if (aid_.empty()) {
            return Unsupported("No AID was supplied when the channel was opened");
        }

        std::vector<uint8_t> command = {0x00, 0xa4, 0x04, 0x02,
                                        static_cast<uint8_t>(aid_.size())};
        command.insert(command.end(), aid_.begin(), aid_.end());
        ndk::ScopedAStatus status = SetChannelToClassByte(&command[0], channel_number_);
        if (!status.isOk()) {
            return status;
        }

        std::vector<uint8_t> response;
        status = backend_->Transmit(std::move(command), &response);
        if (!status.isOk()) {
            return status;
        }
        const uint16_t sw = static_cast<uint16_t>(response[response.size() - 2]) << 8 |
                response.back();
        if ((sw & 0xf000) == 0x9000 || (sw & 0xff00) == 0x6200 ||
            (sw & 0xff00) == 0x6300) {
            select_response_ = std::move(response);
            *selected = true;
            return ndk::ScopedAStatus::ok();
        }
        if ((sw & 0xff00) == 0x6a00) {
            *selected = false;
            return ndk::ScopedAStatus::ok();
        }
        return Unsupported("SELECT NEXT returned an unsupported status word");
    }

  private:
    static ndk::ScopedAStatus SetChannelToClassByte(uint8_t* cla, int8_t channel) {
        const uint8_t channel_number = static_cast<uint8_t>(channel);
        if (channel_number < 4) {
            *cla = static_cast<uint8_t>((*cla & 0xbc) | channel_number);
            return ndk::ScopedAStatus::ok();
        }
        if (channel_number < 20) {
            const bool secure_messaging = ((*cla & 0x40) == 0) && ((*cla & 0x0c) != 0);
            *cla = static_cast<uint8_t>((*cla & 0xb0) | 0x40 | (channel_number - 4));
            if (secure_messaging) {
                *cla |= 0x20;
            }
            return ndk::ScopedAStatus::ok();
        }
        return IllegalArgument("Logical channel number is outside [0, 19]");
    }

    std::shared_ptr<SecureElementBackend> backend_;
    const int8_t channel_number_;
    std::vector<uint8_t> select_response_;
    const std::vector<uint8_t> aid_;
    std::shared_ptr<omapi::ISecureElementListener> listener_;
    std::mutex mutex_;
    bool closed_ = false;
};

class OmapiSession final : public omapi::BnSecureElementSession {
  public:
    explicit OmapiSession(std::shared_ptr<SecureElementBackend> backend)
        : backend_(std::move(backend)) {
        (void)backend_->GetAtr(&atr_);
    }

    ndk::ScopedAStatus getAtr(std::vector<uint8_t>* atr) override {
        std::lock_guard<std::mutex> lock(mutex_);
        *atr = atr_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus close() override {
        return CloseInternal();
    }

    ndk::ScopedAStatus closeChannels() override {
        std::vector<std::shared_ptr<OmapiChannel>> channels;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            channels = channels_;
            channels_.clear();
        }
        for (const auto& channel : channels) {
            (void)channel->close();
        }
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus isClosed(bool* closed) override {
        std::lock_guard<std::mutex> lock(mutex_);
        *closed = closed_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus openBasicChannel(
            const std::vector<uint8_t>& aid, int8_t p2,
            const std::shared_ptr<omapi::ISecureElementListener>& listener,
            std::shared_ptr<omapi::ISecureElementChannel>* channel) override {
        ndk::ScopedAStatus validation = ValidateOpen(aid, p2, listener);
        if (!validation.isOk()) {
            return validation;
        }
        std::vector<uint8_t> select_response;
        ndk::ScopedAStatus status = backend_->OpenBasicChannel(aid, p2, &select_response);
        if (!status.isOk()) {
            return status;
        }
        auto result = ndk::SharedRefBase::make<OmapiChannel>(
                backend_, 0, std::move(select_response), aid, listener);
        AddChannel(result);
        *channel = std::move(result);
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus openLogicalChannel(
            const std::vector<uint8_t>& aid, int8_t p2,
            const std::shared_ptr<omapi::ISecureElementListener>& listener,
            std::shared_ptr<omapi::ISecureElementChannel>* channel) override {
        ndk::ScopedAStatus validation = ValidateOpen(aid, p2, listener);
        if (!validation.isOk()) {
            return validation;
        }
        hwse::LogicalChannelResponse response;
        ndk::ScopedAStatus status = backend_->OpenLogicalChannel(aid, p2, &response);
        if (!status.isOk()) {
            return status;
        }
        auto result = ndk::SharedRefBase::make<OmapiChannel>(
                backend_, response.channelNumber, std::move(response.selectResponse), aid,
                listener);
        AddChannel(result);
        *channel = std::move(result);
        return ndk::ScopedAStatus::ok();
    }

  private:
    ndk::ScopedAStatus ValidateOpen(
            const std::vector<uint8_t>& aid, int8_t p2,
            const std::shared_ptr<omapi::ISecureElementListener>& listener) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (closed_) {
            return IllegalState("Session is closed");
        }
        if (listener == nullptr) {
            return NullPointer("Listener must not be null");
        }
        if (!IsValidAid(aid)) {
            return IllegalArgument("AID length must be zero or between 5 and 16 bytes");
        }
        if (!IsValidP2(p2)) {
            return Unsupported("P2 must be one of 00, 04, 08, or 0c");
        }
        return ndk::ScopedAStatus::ok();
    }

    void AddChannel(const std::shared_ptr<OmapiChannel>& channel) {
        std::lock_guard<std::mutex> lock(mutex_);
        channels_.push_back(channel);
    }

    ndk::ScopedAStatus CloseInternal() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (closed_) {
                return ndk::ScopedAStatus::ok();
            }
            closed_ = true;
        }
        return closeChannels();
    }

    std::shared_ptr<SecureElementBackend> backend_;
    std::vector<uint8_t> atr_;
    std::vector<std::shared_ptr<OmapiChannel>> channels_;
    std::mutex mutex_;
    bool closed_ = false;
};

class OmapiReader final : public omapi::BnSecureElementReader {
  public:
    explicit OmapiReader(std::shared_ptr<SecureElementBackend> backend)
        : backend_(std::move(backend)) {}

    ndk::ScopedAStatus isSecureElementPresent(bool* present) override {
        return backend_->IsCardPresent(present);
    }

    ndk::ScopedAStatus openSession(
            std::shared_ptr<omapi::ISecureElementSession>* session) override {
        bool present = false;
        ndk::ScopedAStatus status = backend_->IsCardPresent(&present);
        if (!status.isOk()) {
            return status;
        }
        if (!present) {
            return ndk::ScopedAStatus::fromServiceSpecificErrorWithMessage(
                    hwse::ISecureElement::IOERROR, "Secure Element is not present");
        }
        auto result = ndk::SharedRefBase::make<OmapiSession>(backend_);
        {
            std::lock_guard<std::mutex> lock(mutex_);
            sessions_.push_back(result);
        }
        *session = std::move(result);
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus closeSessions() override {
        std::vector<std::shared_ptr<OmapiSession>> sessions;
        {
            std::lock_guard<std::mutex> lock(mutex_);
            for (const auto& weak_session : sessions_) {
                if (auto session = weak_session.lock()) {
                    sessions.push_back(std::move(session));
                }
            }
            sessions_.clear();
        }
        for (const auto& session : sessions) {
            (void)session->close();
        }
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus reset(bool* reset_succeeded) override {
        ndk::ScopedAStatus status = backend_->Reset();
        *reset_succeeded = status.isOk();
        return status;
    }

  private:
    std::shared_ptr<SecureElementBackend> backend_;
    std::vector<std::weak_ptr<OmapiSession>> sessions_;
    std::mutex mutex_;
};

class OmapiService final : public omapi::BnSecureElementService {
  public:
    explicit OmapiService(std::shared_ptr<SecureElementBackend> backend)
        : reader_(ndk::SharedRefBase::make<OmapiReader>(std::move(backend))) {}

    ndk::ScopedAStatus getReaders(std::vector<std::string>* readers) override {
        *readers = {kReaderName};
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus getReader(
            const std::string& reader,
            std::shared_ptr<omapi::ISecureElementReader>* result) override {
        if (reader != kReaderName) {
            return IllegalArgument("Only the eSE1 reader is available in recovery");
        }
        *result = reader_;
        return ndk::ScopedAStatus::ok();
    }

    ndk::ScopedAStatus isNfcEventAllowed(
            const std::string& reader, const std::vector<uint8_t>& aid,
            const std::vector<std::string>& package_names, int32_t user_id,
            std::vector<bool>* allowed) override {
        (void)aid;
        (void)user_id;
        if (reader != kReaderName) {
            return IllegalArgument("Unknown Secure Element reader");
        }
        allowed->assign(package_names.size(), false);
        return ndk::ScopedAStatus::ok();
    }

  private:
    std::shared_ptr<OmapiReader> reader_;
};

}  // namespace

int main() {
    android::base::InitLogging(nullptr, android::base::KernelLogger);
    ABinderProcess_setThreadPoolMaxThreadCount(4);
    ABinderProcess_startThreadPool();

    auto backend = std::make_shared<SecureElementBackend>();
    if (!backend->Connect()) {
        LOG(ERROR) << "Failed to initialize the Secure Element backend";
        return 1;
    }

    auto service = ndk::SharedRefBase::make<OmapiService>(backend);
    const binder_status_t status =
            AServiceManager_addService(service->asBinder().get(), kOmapiInstance);
    if (status != STATUS_OK) {
        LOG(ERROR) << "Failed to register " << kOmapiInstance << ": " << status;
        return 1;
    }
    if (!android::base::SetProperty("vendor.omapi_bridge.ready", "1")) {
        LOG(ERROR) << "Failed to publish vendor.omapi_bridge.ready";
        return 1;
    }

    LOG(INFO) << kOmapiInstance << " is ready";
    ABinderProcess_joinThreadPool();
    return 1;
}
