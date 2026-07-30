/*****************************************************************************
*  Copyright Statement:
*  --------------------
*  This software is protected by Copyright and the information contained
*  herein is confidential. The software may not be copied and the information
*  contained herein may not be used or disclosed except with the written
*  permission of MediaTek Inc. (C) 2020
*
*  BY OPENING THIS FILE, BUYER HEREBY UNEQUIVOCALLY ACKNOWLEDGES AND AGREES
*  THAT THE SOFTWARE/FIRMWARE AND ITS DOCUMENTATIONS ("MEDIATEK SOFTWARE")
*  RECEIVED FROM MEDIATEK AND/OR ITS REPRESENTATIVES ARE PROVIDED TO BUYER ON
*  AN "AS-IS" BASIS ONLY. MEDIATEK EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES,
*  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
*  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE OR NONINFRINGEMENT.
*  NEITHER DOES MEDIATEK PROVIDE ANY WARRANTY WHATSOEVER WITH RESPECT TO THE
*  SOFTWARE OF ANY THIRD PARTY WHICH MAY BE USED BY, INCORPORATED IN, OR
*  SUPPLIED WITH THE MEDIATEK SOFTWARE, AND BUYER AGREES TO LOOK ONLY TO SUCH
*  THIRD PARTY FOR ANY WARRANTY CLAIM RELATING THERETO. MEDIATEK SHALL ALSO
*  NOT BE RESPONSIBLE FOR ANY MEDIATEK SOFTWARE RELEASES MADE TO BUYER'S
*  SPECIFICATION OR TO CONFORM TO A PARTICULAR STANDARD OR OPEN FORUM.
*
*  BUYER'S SOLE AND EXCLUSIVE REMEDY AND MEDIATEK'S ENTIRE AND CUMULATIVE
*  LIABILITY WITH RESPECT TO THE MEDIATEK SOFTWARE RELEASED HEREUNDER WILL BE,
*  AT MEDIATEK'S OPTION, TO REVISE OR REPLACE THE MEDIATEK SOFTWARE AT ISSUE,
*  OR REFUND ANY SOFTWARE LICENSE FEES OR SERVICE CHARGE PAID BY BUYER TO
*  MEDIATEK FOR SUCH MEDIATEK SOFTWARE AT ISSUE.
*
*  THE TRANSACTION CONTEMPLATED HEREUNDER SHALL BE CONSTRUED IN ACCORDANCE
*  WITH THE LAWS OF THE STATE OF CALIFORNIA, USA, EXCLUDING ITS CONFLICT OF
*  LAWS PRINCIPLES.  ANY DISPUTES, CONTROVERSIES OR CLAIMS ARISING THEREOF AND
*  RELATED THERETO SHALL BE SETTLED BY ARBITRATION IN SAN FRANCISCO, CA, UNDER
*  THE RULES OF THE INTERNATIONAL CHAMBER OF COMMERCE (ICC).
*
*****************************************************************************/

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <string>
#include <unistd.h>

#include <android-base/logging.h>

#if !defined(ARCH_X86)
#include <linux/bsg.h>
#include <scsi/scsi_bsg_ufs.h>
#include <sys/ioctl.h>

#ifndef SG_IO
#define SG_IO 0x2285
#endif
#endif

#include "boot_region_control_private.h"

namespace android {
namespace bootable {
#if !defined(ARCH_X86)
namespace {

constexpr char kUfsBsgDevice[] = "/dev/ufs-bsg0";

constexpr uint32_t kUpiuTransactionQueryRequest = 0x16;

constexpr uint8_t kQueryOpcodeReadAttribute = 0x03;
constexpr uint8_t kQueryOpcodeWriteAttribute = 0x04;

constexpr uint8_t kQueryFunctionRead = 0x01;
constexpr uint8_t kQueryFunctionWrite = 0x81;

constexpr uint8_t kBootLunEnabledAttribute = 0x00;

constexpr uint32_t kBsgTimeoutMs = 20000;

static __be32 MakeUpiuHeaderDword(
        uint8_t byte3,
        uint8_t byte2,
        uint8_t byte1,
        uint8_t byte0) {
    const uint32_t value =
            (static_cast<uint32_t>(byte3) << 24) |
            (static_cast<uint32_t>(byte2) << 16) |
            (static_cast<uint32_t>(byte1) << 8) |
            static_cast<uint32_t>(byte0);

    return htonl(value);
}

static bool UfsQueryBootLun(bool write, uint32_t* value) {
    if (value == nullptr) {
        LOG(ERROR) << "UFS BSG query received a null value pointer";
        return false;
    }

    const int fd = open(kUfsBsgDevice, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        LOG(ERROR) << "Failed to open " << kUfsBsgDevice
                   << ": " << strerror(errno);
        return false;
    }

    struct ufs_bsg_request request = {};
    struct ufs_bsg_reply reply = {};
    struct sg_io_v4 io = {};

    const uint8_t opcode =
            write
                    ? kQueryOpcodeWriteAttribute
                    : kQueryOpcodeReadAttribute;

    const uint8_t query_function =
            write
                    ? kQueryFunctionWrite
                    : kQueryFunctionRead;

    request.msgcode = kUpiuTransactionQueryRequest;

    request.upiu_req.header.dword_0 =
            MakeUpiuHeaderDword(
                    kUpiuTransactionQueryRequest,
                    0,
                    0,
                    0);

    request.upiu_req.header.dword_1 =
            MakeUpiuHeaderDword(
                    0,
                    query_function,
                    0,
                    0);

    request.upiu_req.qr.opcode = opcode;
    request.upiu_req.qr.idn = kBootLunEnabledAttribute;
    request.upiu_req.qr.index = 0;
    request.upiu_req.qr.selector = 0;

    if (write) {
        request.upiu_req.qr.value = htonl(*value);
    }

    io.guard = 'Q';
    io.protocol = BSG_PROTOCOL_SCSI;
    io.subprotocol = BSG_SUB_PROTOCOL_SCSI_TRANSPORT;

    io.request_len = sizeof(request);
    io.request = static_cast<__u64>(
            reinterpret_cast<uintptr_t>(&request));

    io.max_response_len = sizeof(reply);
    io.response = static_cast<__u64>(
            reinterpret_cast<uintptr_t>(&reply));

    io.timeout = kBsgTimeoutMs;

    errno = 0;
    const int result = ioctl(fd, SG_IO, &io);
    const int saved_errno = errno;

    close(fd);

    if (result < 0) {
        LOG(ERROR) << "UFS BSG SG_IO failed: "
                   << strerror(saved_errno)
                   << " (" << saved_errno << ")";
        return false;
    }

    if (reply.result != 0) {
        LOG(ERROR) << "UFS BSG kernel result failed: "
                   << reply.result;
        return false;
    }

    const uint32_t upiu_result =
            ntohl(reply.upiu_rsp.header.dword_1) & 0xffffu;

    if (upiu_result != 0) {
        LOG(ERROR) << "UFS query response failed: 0x"
                   << std::hex << upiu_result;
        return false;
    }

    *value = ntohl(reply.upiu_rsp.qr.value);
    return true;
}

static bool ufs_set_active_boot_part(int boot) {
    if (boot != 1 && boot != 2) {
        LOG(ERROR) << "Invalid UFS boot LUN value: " << boot;
        return false;
    }

    uint32_t requested = static_cast<uint32_t>(boot);

    LOG(INFO) << "Writing UFS boot LUN through BSG: "
              << requested;

    if (!UfsQueryBootLun(true, &requested)) {
        LOG(ERROR) << "Failed to write UFS boot LUN";
        return false;
    }

    uint32_t readback = 0;

    if (!UfsQueryBootLun(false, &readback)) {
        LOG(ERROR) << "Failed to read back UFS boot LUN";
        return false;
    }

    if (readback != static_cast<uint32_t>(boot)) {
        LOG(ERROR) << "UFS boot LUN verification failed: expected "
                   << boot << ", read " << readback;
        return false;
    }

    LOG(INFO) << "UFS boot LUN verified: " << readback;
    return true;
}

}  // namespace

bool BootControlExt::SetBootRegionSlot(unsigned int slot) {
    LOG(INFO) << "SetBootRegionSlot slot=" << slot;

    if (slot >= 2) {
        LOG(ERROR) << "Wrong slot value: " << slot;
        return false;
    }

    const int boot_part = slot == 0 ? 1 : 2;

    return ufs_set_active_boot_part(boot_part);
}
#else
bool BootControlExt::SetBootRegionSlot(unsigned int slot) {
  return true;
}
#endif //#if !defined(ARCH_X86)
}
}
