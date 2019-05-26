#!/usr/bin/env python3

from aem import *


# update PID before running:
pid = 90323



p = Application(pid=pid)

print(p.event(b'aevtodoc', {b'----': "/Users/foo/README.txt"}).send(timeout=240))

print(p.event(b'coregetd', {b'----': app.elements(b'docu').byindex(1).property(b'ctxt')}).send(timeout=240))

p.event(b'coreclos', {b'----': app.elements(b'docu')}).send(timeout=240)

#p.event(b'aevtquit').send(timeout=240)
