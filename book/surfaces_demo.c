/* SPDX-License-Identifier: Apache-2.0 */
/* Copyright 2026 lituus-lab */
/* Run by book/surfaces.nim during the book build; its output is the page's. */
#include <stdio.h>
#include "UniChecksum.h"

int main(void) {
  const uint8_t check[] = {'1','2','3','4','5','6','7','8','9'};
  uint32_t state;

  printf("unichecksum_version()             = %s\n", unichecksum_version());
  printf("unichecksum_crc32(\"123456789\")    = %08X\n",
         unichecksum_crc32(check, sizeof check));
  printf("unichecksum_crc64(\"123456789\")    = %016llX\n",
         (unsigned long long)unichecksum_crc64(check, sizeof check));

  /* Out of domain: the boundary clamps rather than unwinding into C. */
  printf("unichecksum_crc32(NULL, 8)        = %08X   (nothing was read)\n",
         unichecksum_crc32(NULL, 8));
  state = unichecksum_crc32_init();
  printf("crc32_update(state, NULL, 8)      = %08X   (state, unchanged)\n",
         unichecksum_crc32_update(state, NULL, 8));
  return 0;
}
