# 
#
# Copyright (c) 2015 NetApp, Inc.
# All rights reserved.

all: sur fast_chown

sur: sur.c
	sudo gcc -o sur sur.c
	sudo chmod 4755 sur

fast_chown: simple_chown.c
	sudo gcc -O2 -o fast_chown fast_chown.c
	sudo chmod 4755 fast_chown

clean:
	rm -rf sur fast_chown

