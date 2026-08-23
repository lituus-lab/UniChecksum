# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Shell-free: `pwd` and `rm` are unavailable under mingw32-make on Windows.
ifeq ($(origin CC),default)
  ifeq ($(OS),Windows_NT)
    CC := gcc
  else
    CC := cc
  endif
endif

ROOT   := $(CURDIR)/../..
CFLAGS := -I$(ROOT)/include -O2 -Wall -Wextra -std=c11
LIB    := $(ROOT)/libUniChecksum.a

ifeq ($(OS),Windows_NT)
  BIN  := test_unichecksum.exe
  RUN  := $(BIN)
  RM_F := del /q
else
  BIN  := test_unichecksum
  RUN  := ./$(BIN)
  RM_F := rm -f
endif

.PHONY: all run clean
all: run
run: $(BIN)
	$(RUN)
$(BIN): test_unichecksum.c $(ROOT)/include/UniChecksum.h $(LIB)
	$(CC) $(CFLAGS) -o $(BIN) test_unichecksum.c $(LIB)
# File target, not phony: `nimble ctest` already built the lib, don't redo it.
# Reaching this rule means make was invoked directly; say so instead of
# shelling out, which `cd x && y` would need and mingw32-make cannot do.
$(LIB):
	$(error $(LIB) is missing - run `nimble clibStatic` from the repository root)
clean:
	$(RM_F) $(BIN)
