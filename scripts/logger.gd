extends Node

var allow_info := true
var allow_dbg := true
var allow_err := true
var T0 := MainGlobals.timems()
func time_prefix():
	var now = MainGlobals.timems()
	return "%06d: " % (now-T0)

func info(s1,s2='',s3='',s4='',s5='',s6='',s7='',s8='') -> void:
	if allow_info and OS.is_debug_build():
		print(time_prefix(),s1,s2,s3,s4,s5,s6,s7,s8)

func dbg(s1,s2='',s3='',s4='',s5='',s6='',s7='',s8='') -> void:
	if allow_dbg and OS.is_debug_build():
		print(time_prefix(),s1,s2,s3,s4,s5,s6,s7,s8)

func err(s1,s2='',s3='',s4='',s5='',s6='',s7='',s8='') -> void:
	if allow_err:
		print(time_prefix(),s1,s2,s3,s4,s5,s6,s7,s8)