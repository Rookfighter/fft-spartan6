# twiddle.py
#
# Created on: 15 May 2017
#     Author: Fabian Meyer

import argparse
import math

VERSION = '0.1.0'


def parse_args():
    '''Parse command line arguments.'''

    parser = argparse.ArgumentParser(
        description="Calculate twiddle factor.")

    parser.add_argument('--version', action='version', version=VERSION)
    parser.add_argument('-n', dest='n', type=int, required=True,
        help='Size of FFT (N-point FFT).')

    return parser.parse_args()


def calc_twiddle(n):
    result = []

    for i in range(n):
        tf = (round(math.cos(2 * math.pi * i / n)),
              round(math.sin(2 * math.pi * i / n), 4))
        result.append(tf)

    return result


if __name__ == '__main__':
    cfg = parse_args()
    print(calc_twiddle(cfg.n))
