# twiddle.py
#
# Created on: 15 May 2017
#     Author: Fabian Meyer

import argparse
import math

VERSION = '0.1.0'
N = 16


def parse_args():
    '''Parse command line arguments.'''

    parser = argparse.ArgumentParser(
        description="Calculate twiddle factor.")

    parser.add_argument('--version', action='version', version=VERSION)
    parser.add_argument('-f', dest='f', type=int, required=True,
        help='Frequency of sinus.')
    parser.add_argument('-a', dest='a', type=int, required=True,
        help='Amplitude of sinus.')

    return parser.parse_args()


def calc_sin(a, f):
    result = []

    for i in range(N):
        val = a * math.sin(2 * math.pi * f * (float(i) / 16.0))
        result.append((round(val, 4), 0.0))

    return result


def sin_to_str(mysin):
    tf_strs = [str(tf) for tf in mysin]
    return '(\n    {}\n)'.format(',\n    '.join(tf_strs))


if __name__ == '__main__':
    cfg = parse_args()
    mysin = calc_sin(cfg.a, cfg.f)
    print(sin_to_str(mysin))
