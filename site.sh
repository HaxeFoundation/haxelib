#!/bin/bash
cd server
# starting server on port 2000, because binding port 80 requires root privileges,
# which might be a bad idea
nekotools server -rewrite