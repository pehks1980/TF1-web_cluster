#!/bin/bash

echo "<h1>Hello World</h1> <p> DB addr: ${dbaddress} <br> DB port: ${dbport}</p>" > index.html
#detach from tty and silently run in bg
#(note with nohup file is created w standart output - nohup.out)
nohup busybox httpd -f -p "${s_port}" > /dev/null 2>&1 &
