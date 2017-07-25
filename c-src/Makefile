# Makefile
#
# Created on: 17 Jul 2017
#     Author: Fabian Meyer

CFLAGS=-Wall -g
LDFLAGS=

SRC = i2c_fft.c
OBJ = $(SRC:%.c=%.o)
BIN = $(SRC:%.c=%)
HDR = i2c.h

.PHONY: all clean

all: $(BIN)

clean:
	@rm -f $(OBJ) $(BIN)

%.o: %.c
	@echo "  CC $@"
	@$(CC) $(CFLAGS) -c $<

i2c_dip_lcd: $(OBJ)
	@echo "  LD $@"
	@$(CC) $(CFLAGS) $(LDFLAGS)-o $@ $(OBJ)
