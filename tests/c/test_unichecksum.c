// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <stdint.h>
#include "UniChecksum.h"

static int failures = 0;

static void check_u32(const char *name, uint32_t got, uint32_t want) {
  if (got != want) { printf("FAIL %s: got 0x%08X want 0x%08X\n", name, got, want); failures++; }
  else printf("ok   %s = 0x%08X\n", name, got);
}

static void check_u64(const char *name, uint64_t got, uint64_t want) {
  if (got != want) {
    printf("FAIL %s: got 0x%016llX want 0x%016llX\n", name,
           (unsigned long long)got, (unsigned long long)want);
    failures++;
  } else printf("ok   %s = 0x%016llX\n", name, (unsigned long long)got);
}

static void check_str(const char *name, const char *got, const char *want) {
  if (strcmp(got, want) != 0) { printf("FAIL %s: got \"%s\" want \"%s\"\n", name, got, want); failures++; }
  else printf("ok   %s = \"%s\"\n", name, got);
}

/* "123456789" is the check value every CRC catalogue publishes. */
static const uint8_t CHECK[9] = {'1','2','3','4','5','6','7','8','9'};
static const uint8_t ABC[3] = {'a','b','c'};

int main(void) {
  check_u32("crc32(\"123456789\")", unichecksum_crc32(CHECK, sizeof CHECK), 0xCBF43926u);
  check_u32("crc32(\"abc\")", unichecksum_crc32(ABC, sizeof ABC), 0x352441C2u);
  check_u32("crc32(empty)", unichecksum_crc32(ABC, 0), 0u);
  check_u32("crc32(NULL)", unichecksum_crc32(NULL, 8), 0u);

  check_u64("crc64(\"123456789\")", unichecksum_crc64(CHECK, sizeof CHECK),
            0x995DC9BBDF1939FAull);
  check_u64("crc64(\"abc\")", unichecksum_crc64(ABC, sizeof ABC), 0x2CD8094A1A277627ull);
  check_u64("crc64(empty)", unichecksum_crc64(ABC, 0), 0ull);

  check_u32("adler32(\"123456789\")", unichecksum_adler32(CHECK, sizeof CHECK), 0x091E01DEu);
  check_u32("adler32(\"abc\")", unichecksum_adler32(ABC, sizeof ABC), 0x024D0127u);
  check_u32("adler32(empty)", unichecksum_adler32(ABC, 0), 1u);

  /* Streaming the same bytes in two pieces must match the one-shot call. */
  {
    uint32_t c = unichecksum_crc32_update(unichecksum_crc32_init(), CHECK, 4);
    c = unichecksum_crc32_final(unichecksum_crc32_update(c, CHECK + 4, 5));
    check_u32("crc32 split 4+5", c, 0xCBF43926u);

    uint64_t d = unichecksum_crc64_update(unichecksum_crc64_init(), CHECK, 4);
    d = unichecksum_crc64_final(unichecksum_crc64_update(d, CHECK + 4, 5));
    check_u64("crc64 split 4+5", d, 0x995DC9BBDF1939FAull);

    uint32_t a = unichecksum_adler32_update(unichecksum_adler32_init(), CHECK, 4);
    a = unichecksum_adler32_final(unichecksum_adler32_update(a, CHECK + 4, 5));
    check_u32("adler32 split 4+5", a, 0x091E01DEu);
  }

  /* A NULL or empty span leaves a running state untouched. */
  check_u32("crc32_update(NULL) keeps state",
            unichecksum_crc32_update(0x12345678u, NULL, 4), 0x12345678u);
  check_u32("adler32_update(empty) keeps state",
            unichecksum_adler32_update(0x00620062u, ABC, 0), 0x00620062u);
  /* Halves at or above the modulus cannot come from this API: rejected. */
  check_u32("adler32_update rejects an impossible state",
            unichecksum_adler32_update(0xFFFFFFFFu, ABC, sizeof ABC), 0xFFFFFFFFu);

  check_u32("crc32_final(crc32_init()) is 0", unichecksum_crc32_final(unichecksum_crc32_init()), 0u);
  check_u32("adler32_init is 1", unichecksum_adler32_init(), 1u);
  check_str("version", unichecksum_version(), UNICHECKSUM_VERSION);

  if (failures == 0) { printf("\nAll C ABI tests passed.\n"); return 0; }
  printf("\n%d C ABI test(s) FAILED.\n", failures);
  return 1;
}
