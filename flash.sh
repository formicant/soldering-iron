#! /bin/bash

avrdude -c usbasp-clone -p t2313 -B 125kHz -U flash:w:soldering-iron.hex:a
