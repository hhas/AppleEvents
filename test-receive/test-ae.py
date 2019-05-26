#!/usr/bin/env python3

from aem import *

pid = 86469 # update

Application(pid=pid).event(b'aevtodoc', {b'----': "/Users"}).send(timeout=240)

