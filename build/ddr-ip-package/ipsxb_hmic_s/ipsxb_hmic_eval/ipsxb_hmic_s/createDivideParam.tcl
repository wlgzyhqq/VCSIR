proc createDivideParam {clkin_freq exp_clkout_freq} {
	global idiv
	global fdiv
	global odiv
	global vco_freq
	global act_clkout_freq
	
    set clkin_freq_min 5
    set clkin_freq_max 625
  
  set pfd_freq_min 20
  set pfd_freq_max 450
  #VCO frequency range:[vco_freq_min, vco_freq_max] or [vco_freq_min_ext, vco_freq_max_ext]
  set vco_freq_min 600
  set vco_freq_max 800  
  set act_clkout_freq 0  
  set idiv 0
  set fdiv 0
  set odiv 0
  set vco_freq 0
  set act_clkout_freq 3000
  #idiv_loop_max
  #set idiv_loop_max [expr int($clkin_freq / $pfd_freq_min)]
  #if {$idiv_loop_max >= 128} {
  #	set idiv_loop_max 128
  #} 
  #set idiv_loop_min [expr int($clkin_freq /double($pfd_freq_max) + 0.99999999999)]
  #if {$idiv_loop_min <= 1} {
  #	set idiv_loop_min 1
  #}  	
  #for {set i $idiv_loop_min} {$i <= $idiv_loop_max} {incr i} {
  	#set idiv_temp $i
  	set idiv_temp 1
  	set fdiv_loop_min [expr int($vco_freq_min * $idiv_temp /double($clkin_freq) + 0.9999999999)]
  	if {$fdiv_loop_min <= 1} {
  		set fdiv_loop_min 1
  	}
  	set fdiv_loop_max [expr int($vco_freq_max * $idiv_temp / $clkin_freq)]
  	if {$fdiv_loop_max >= 64} {
  		set fdiv_loop_max 64
  	}
  	for {set j $fdiv_loop_min} {$j <= $fdiv_loop_max} {incr j} {
  	set fdiv_temp $j
  	set odiv_temp [expr int(double($clkin_freq)*double($fdiv_temp)/double($idiv_temp)/double($exp_clkout_freq))]
  	for {set m 1} {$m <= 2} {incr m} {
  	if {$odiv_temp <= 1} {
  	set odiv_temp 1
    }
    if {$odiv_temp >= 128} {
    set odiv_temp 128 
    }
  	set vco_freq_temp [expr double($clkin_freq)*double($fdiv_temp)/double($idiv_temp)]
  	set clkout_freq [expr double($clkin_freq)*double($fdiv_temp)/double($idiv_temp)/double($odiv_temp)]
  	set check_a [expr abs(double($clkout_freq) - double($exp_clkout_freq))]
    set check_b [expr abs(double($act_clkout_freq) - double($exp_clkout_freq))]
    if {$check_a < $check_b } {
    set act_clkout_freq $clkout_freq
    set vco_freq $vco_freq_temp
    set idiv $idiv_temp
    set fdiv $fdiv_temp
    set odiv $odiv_temp
    } 
    incr odiv_temp
    }
  	}
  #}
  
#    puts "clkin=$clkin_freq"
#    puts "act_freq=$act_clkout_freq,idiv=$idiv,fdiv=$fdiv,odiv=$odiv,vco=$vco_freq"
}


