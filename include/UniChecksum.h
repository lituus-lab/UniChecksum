// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#ifndef UNICHECKSUM_H
#define UNICHECKSUM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNICHECKSUM_VERSION_MAJOR 0
#define UNICHECKSUM_VERSION_MINOR 1
#define UNICHECKSUM_VERSION_PATCH 0
#define UNICHECKSUM_VERSION "0.1.0"

#define UNICHECKSUM_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNICHECKSUM_VERSION_MAJOR > (ma)) || \
   (UNICHECKSUM_VERSION_MAJOR == (ma) && UNICHECKSUM_VERSION_MINOR > (mi)) || \
   (UNICHECKSUM_VERSION_MAJOR == (ma) && UNICHECKSUM_VERSION_MINOR == (mi) && \
    UNICHECKSUM_VERSION_PATCH >= (pa)))

/* IEEE 802.3 polynomial in reflected form (0x04C11DB7 bit-reversed). */
#define UNICHECKSUM_CRC32_POLYNOMIAL 0xEDB88320u
/* ECMA-182 polynomial in reflected form (0x42F0E1EBA9EA3693 bit-reversed). */
#define UNICHECKSUM_CRC64_POLYNOMIAL 0xC96C5795D7870F42ull
/* Largest prime below 2^16: the modulus both Adler-32 halves are reduced by. */
#define UNICHECKSUM_ADLER32_MODULUS 65521u

/* Static version string; do not free. */
const char *unichecksum_version(void);

/* Every function below never raises and is reentrant. A NULL `data`, a zero
 * `length`, or a `length` too large to address leaves the state untouched. */

/* CRC-32 (IEEE 802.3), as used by zlib, PNG, gzip and ZIP. A state becomes a
 * checksum only after unichecksum_crc32_final. */
uint32_t unichecksum_crc32_init(void);
uint32_t unichecksum_crc32_update(uint32_t state, const uint8_t *data, size_t length);
uint32_t unichecksum_crc32_final(uint32_t state);
/* CRC-32 of a whole span. NULL or empty input is 0. */
uint32_t unichecksum_crc32(const uint8_t *data, size_t length);

/* CRC-64/XZ (ECMA-182 polynomial, reflected), the check the .xz container
 * carries. A state becomes a checksum only after unichecksum_crc64_final. */
uint64_t unichecksum_crc64_init(void);
uint64_t unichecksum_crc64_update(uint64_t state, const uint8_t *data, size_t length);
uint64_t unichecksum_crc64_final(uint64_t state);
/* CRC-64/XZ of a whole span. NULL or empty input is 0. */
uint64_t unichecksum_crc64(const uint8_t *data, size_t length);

/* Adler-32 (RFC 1950). unichecksum_adler32_final is the identity; it exists so
 * all three families share one init/update/final shape. A state whose halves
 * are not both below UNICHECKSUM_ADLER32_MODULUS cannot come from this API and
 * is returned unchanged by unichecksum_adler32_update. */
uint32_t unichecksum_adler32_init(void);
uint32_t unichecksum_adler32_update(uint32_t state, const uint8_t *data, size_t length);
uint32_t unichecksum_adler32_final(uint32_t state);
/* Adler-32 of a whole span. NULL or empty input is 1. */
uint32_t unichecksum_adler32(const uint8_t *data, size_t length);

#ifdef __cplusplus
}
#endif

#endif /* UNICHECKSUM_H */
