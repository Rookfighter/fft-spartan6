/* i2c_fft.c
 *
 * Created on: 17 Jul 2017
 *     Author: Fabian Meyer
 *
 * Basic communication application to send values to an FFT on
 * the E2LP FPGA platform.
 *
 * This code is largely based on Sebastian Sester's code.
 * Original file header:
 *
 * I2C implementation for the Marvell Armada 1500
 *
 * This code was written by
 * Sebastian Sester <mail@sebastiansester.de>
 * but bases mostly on the I2C-code by RTRK.
 *
 * This code requires the i2c.h-headerfile from
 * the GoogleTV source code.
 *
 * Compile this code with
 * $CC -o i2c i2c.c
 */

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <linux/i2c.h>
#include "i2c.h"

// The bus to use.
#define TWSI_BUS "/dev/twsi0"

#define SLV_ADDR 0x20
#define OPSET    0x01
#define OPRUN    0x02
#define OPGET    0x03

static int twsi_device = -1;

// Set the I2C speed to the given speed.
// Please have a look at i2c.h:19ff for valid speeds.
int i2c_set_speed(uint32_t speed) {
    galois_twsi_speed_t twsi_speed_cfg;
    twsi_speed_cfg.mst_id     = 0;
    twsi_speed_cfg.speed_type = TWSI_STANDARD_SPEED;
    twsi_speed_cfg.speed      = speed;
    if (ioctl(twsi_device, TWSI_IOCTL_SETSPEED, &twsi_speed_cfg))
        return -1;
    return 0;
}

// Initialize I2C.
// This will open the bus and set a default speed of 100 KHz.
int i2c_init (void) {
    twsi_device = open(TWSI_BUS, I2C_RDWR);
    if (twsi_device < 0)
        return -1;

    // Start slowly (compatibility mode)
    return i2c_set_speed(TWSI_SPEED_100);
}

// Perform an action on the I2C bus.
// You can either write data (writeBufferLength > 0, readBufferLength == 0)
// or read data (writeBufferLength > 0, readBufferLength > 0).
// (Normally read-commands are issued by writing the address to read and then
// reading the data that's shifted out)
//
// Please note that the slave address is supposed to be a 7 bit address; the
// last bit (0/1) is attached depending on the operation itself (write/read).
int i2c_read_write (uint8_t slv_addr, uint8_t * wr_buf,
                  uint8_t wr_cnt, uint8_t * rd_buf,
                  uint8_t rd_cnt) {
    if (twsi_device < 0) {
        printf("Can't access bus: %s\n", strerror(errno));
        return -1;
    }
    galois_twsi_rw_t twsiTransfer;

    // Hard wired part
    twsiTransfer.mst_id = 0;
    twsiTransfer.addr_type = TWSI_7BIT_SLAVE_ADDR;
    // User defined part
    twsiTransfer.slv_addr = slv_addr;
    twsiTransfer.wr_cnt = wr_cnt;
    twsiTransfer.wr_buf = wr_buf;
    twsiTransfer.rd_cnt = rd_cnt;
    twsiTransfer.rd_buf = rd_buf;
    if (ioctl(twsi_device, TWSI_IOCTL_READWRITE, &twsiTransfer))
        return -1;
    return 0;
}

// Close the I2C connection (normally only necessary when the program ends)
int i2c_close () {
    if (twsi_device < 0) {
        printf("Can't access bus: %s\n", strerror(errno));
        return -1;
    }
    close(twsi_device);
    return 0;
}

static int FFT_VALS[16] = {
        0,
        382,
        707,
        923,
        1000,
        923,
        707,
        382,
        0,
        -382,
        -707,
        -923,
        -707,
        -382
};



int main(int argc, char * argv[]) {
    uint8_t data[64];
    int vals[16];
    int ret;
    int i;

    printf("\n");
    printf("I2C fft application\n");
    printf("=======================\n");
    printf("\n");

    ret = i2c_init();
    if(ret)
    {
        fprintf(stderr, "Failed to init I2C: %s\n", strerror(errno));
        return 1;
    }

    // first send fft values
    data[0] = OPSET;
    for(i = 0; i < 15; ++i) {
        int idx = (i*3)+1;
        data[idx] = FFT_VALS[i] >> 16 & 0xff;
        data[idx+1] = FFT_VALS[i] >> 8 & 0xff;
        data[idx+2] = FFT_VALS[i] & 0xff;
    }

    printf("Sending out data:\n");
    for(i = 0; i < 15; ++i) {
        printf("  %d\n", FFT_VALS[i]);
    }

    // send values such that FFT can store them in its memory bank
    ret = i2c_read_write(SLV_ADDR,
        data, 49,
        NULL, 0);
    if(ret)
    {
        fprintf(stderr, "Failed to write I2C: %s\n", strerror(errno));
        i2c_close();
        return -1;
    }

    // send the run command for the board
    data[0] = OPRUN;
    ret = i2c_read_write(SLV_ADDR,
        data, 1,
        NULL, 0);

    usleep(500);

    // send get command to read out results
    data[0] = OPGET;
    ret = i2c_read_write(SLV_ADDR,
        data, 1,
        NULL, 0);

    // receive values from FPGA
    ret = i2c_read_write(SLV_ADDR,
        NULL, 0,
        data, 48);

    for(i = 0; i < 15; ++i) {
        int idx = i*3;
        vals[i] = data[idx] << 16 & data[idx+1] << 8 & data[idx+2];
    }

    printf("Received data:\n");
    for(i = 0; i < 15; ++i) {
        printf("  %d\n", vals[i]);
    }


    if(ret)
        fprintf(stderr, "Failed to read: %s\n", strerror(errno));

    i2c_close();

    return ret;
}
