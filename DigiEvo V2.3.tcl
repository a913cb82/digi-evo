######################################################################
##	DigiEvo V2.2 - Copyright (C) 2009 a913cb82				##
##	Inspired by Tierra, Avida and Nanopond:							##
##	Tierra	: life.ou.edu/tierra/									##
##	Avida 	: avida.devosoft.org/									##
##	Nanopond: adam.ierymenko.name/nanopond.shtml					##
##==================================================================##
##	About the Program:												##
##		I was interested in evolution and life, and became curious 	##
##	as to whether life could evolve on computers. I originally 		##
##	thought of using normal assembly, however I quickly learnt that ##
##	it would break if mutated. I then decided to make my own basic	##
##	virtual computer to experiment with.							##
##		The "universe" is a 1 dimensional array of cells, and all	##
##	commands treat cells as being relative to the cell being		##
##	executed, with it's position as 0.								##
##		The program has a 5-bit instruction set, numbered 0-31. It	##
##	is loosely based on BF (muppetlabs.com/~breadbox/bf/), a very	##
##	simple, 8 instruction, turing complete language.				##
##		The language uses a stack, and each organism has 8 registers##
##	for storing values. Each command uses either the current value	##
##	or the current and element after current value on the stack.	##
##		Each cell has it's own section of memory. Any cell can 		##
##	access any other cell's memory to read from, delete, or add code##
##	to the end of it.												##
##------------------------------------------------------------------##
##	How it works:													##
##		The main loop will execute 1 command from every cell, and	##
##	increment each cells step.										##
##		Every time a piece of code is about to be executed by a		##
##	cell, there is a chance of the command about to be executed 	##
##	being changed permanently.										##
##		Every astme steps, the whole simulation is saved.			##
##		The cell's colour is an RGB value based on it's instructions##
##	and the length of it's code (longer=brighter).					##
##		Through this process, a program which can reproduce itself	##
##	faster through any way possible (shorter code, self-assembly,	##
##	assembler/deleter bots etc) will take over the simulation.		##
##		Each command available is a procedure (like a function		##
##	in c), which has the added benefit of allowing them to be		##
##	modified as a simulation is running.							##
##		The call command, rather than using an address, searches	##
##	for a pattern of 4 nop commands (idea from Tierra).				##
##------------------------------------------------------------------##
##	The instruction set:											##
##	00	-	nop0			10	-	call							##
##	01	-	nop1			11	-	return							##
##	02	-	and				12	-	move pointer right				##
##	03	-	or				13	-	move pointer left				##
##	04	-	xor				14	-	increment						##
##	05	-	add				15	-	decrement						##
##	06	-	subtract		16	-	code length						##
##	07	-	multiply		17	-	read code						##
##	08	-	divide			18	-	zero							##
##	09	-	more-than		19	-	delete							##
##	0a	-	less-than		1a	-	copy							##
##	0b	-	equal-to		1b	-									##
##	0c	-	set reg			1c	-									##
##	0d	-	read reg		1d	-									##
##	0e	-	shift right		1e	-									##
##	0f	-	shift left		1f	-									##
######################################################################
package require Tk
#============================================
#SIMULATION SETTINGS
#============================================
set simon -1
set ns 0
set drawlst ""
set mutcount 0
#============================================
#TUNABLE PARAMETERS
#============================================
#If debug is 1 info is printed for every command executed for debugtme microseconds
set debug 0
set debugtme 100
#Every astme steps save sim
set astme 100000
#Prefix for autosaved sims
set simname SimName
#Code to be inserted when add code button pressed
set scode "StartCode.txt"

#Chance of mutation on every command executed
set mutchance 0.0001

#Redraw every redrawtme steps if redraw=1
set redrawtme 1
set redraw 1
#Universe size
set cores 3000
#Cell size
set cellx 15
set celly 5
set simx [expr {int(600/$cellx)}]
set simy [expr {int($cores/$simx)}]
#Stacksize (must be power of 2)
set stacksize 15
#Max code length (must be power of 2)
set maxdna 255

#============================================
#SET UP CELL VARIABLES
for {set a 1} {$a<=$cores} {incr a} {
	set dna($a) ""
	for {set n 0} {$n<$maxdna} {incr n} {lappend dna($a) 0}
	set step($a) 0
	set col($a) #000000
	set cpu($a) 0
	set reg($a,0) 0 ; set reg($a,1) 0 ; set reg($a,2) 0 ; set reg($a,3) 0 ; set reg($a,4) 0
	set reg($a,5) 0 ; set reg($a,6) 0 ; set reg($a,7) 0
	set aptr($a) 0
	set sptr($a) 0
	set sstp($a) 0
	for {set n 0} {$n<=$stacksize} {incr n} {
		lappend stack($a) 0
	}
	lappend drawlst $a
}

#============================================
#GUI
#============================================
frame .toparea
grid .toparea -in . -row 1 -column 1
#Toparea divided into left and right of toparea
frame .leftarea
grid .leftarea -in .toparea -row 1 -column 1

frame .rightarea
grid .rightarea -in .toparea -row 1 -column 2

#Top-left
#=========
#Mutation section
entry .mutc -textvariable mutchance -width 10
label .mutcl -text "Mut chance:"

grid .mutcl -in .leftarea -row 1 -column 1 -sticky e
grid .mutc -in .leftarea -row 1 -column 2 -sticky w

#Add code and start sim
entry .seed -textvariable scode
button .addcode -text "Add Code" -command "addcode"
button .start -text "Start/Stop" -command "startstopbut"

grid .seed -in .leftarea -row 2 -column 1
grid .addcode -in .leftarea -row 2 -column 2 -sticky ew
grid .start -in .leftarea -row 3 -column 2 -sticky ew
#Top-right
#=========
#General settings
label .snamel -text "Sim name:"
entry .sname -textvariable simname -width 10
button .lsimbut -text "Load sim" -command "loadsim"
label .astmel -text "Autosave time:"
entry .astme -textvariable astme -width 10

grid .snamel -in .rightarea -row 3 -column 1 -sticky e
grid .sname -in .rightarea -row 3 -column 2 -sticky w
grid .lsimbut -in .rightarea -row 3 -column 3 -sticky ew
grid .astmel -in .rightarea -row 4 -column 1 -sticky e
grid .astme -in .rightarea -row 4 -column 2 -sticky w

label .coresl -text "Core size:"
entry .cores -textvariable cores -width 10
label .mdnal -text "Max code:"
entry .mdna -textvariable maxdna -width 10

grid .coresl -in .rightarea -row 5 -column 1 -sticky e
grid .cores -in .rightarea -row 5 -column 2 -sticky w
grid .mdnal -in .rightarea -row 6 -column 1 -sticky e
grid .mdna -in .rightarea -row 6 -column 2 -sticky w

#Middle (-in . -row 2&3)
#==========
#create canvas for putting stuff on
set cx [expr {$simx*$cellx}]
set cy [expr {$simy*$celly}]
canvas .universe -width $cx -height $cy -bg black
grid .universe -in . -row 3 -column 1
#simx=75
#simy=40
#create each cell
for {set n 1} {$n<$cores} {incr n} {
	set ypos [expr {int(($n-1)/$simx)}]	;#75=0		1=0
	set xpos [expr {($n+$simx)%$simx}]	;#75=0		1=1
	if {$xpos==0} {set xpos $simx}
	set t [expr {$ypos*$celly}]			;#0*5=0		0*5=0
	set b [expr {($ypos+1)*$celly}]		;#0*5=0		1*5=5
	set l [expr {($xpos-1)*$cellx}]		;#-1*15=-15	0*15=0
	set r [expr {$xpos*$cellx}]			;#0*15=0	1*15=15
	.universe create rectangle $l $t $r $b -tag cell($n) -fill black -outline black
}
#Bottom (-in . -row 4)
#======
frame .botarea
grid .botarea -in . -row 4 -column 1
#Number of steps of simulation
label .nsl -textvariable nslab
grid .nsl -in .botarea -row 1 -column 1 -sticky w

#MOUSECLICKS AND BUTTON PROCS
#============================
bind .universe <ButtonPress-1> "mouseclick %x %y"
proc mouseclick {x y} {
	global cores
	global redraw
	global simx
	global simy
	
	set item [.universe find overlapping $x $y $x $y]
	set coords [.universe coords $item]
	
	set targt 0
	set targl 0

	set l [lindex $coords 0]
	set t [lindex $coords 1]
	set r [lindex $coords 2]
	set b [lindex $coords 3]
	set n 0
	if {$l>0 && $t>0} {
		while {$n<$cores && $l!=$targl} {
			incr n
			set targl [lindex [.universe coords cell($n)] 0]
		}
		while {$n<$cores && $t!=$targt} {
			incr n $simx
			set targt [lindex [.universe coords cell($n)] 1]
		}
	}
	if {$n<$cores && $n>0} {
		puts "Cell $n"
		upvar step($n) step
		upvar dna($n) dna
		upvar aptr($n) aptr
		upvar stack($n) stack
		upvar col($n) col
		upvar cpu($n) cpu
		upvar reg($n,0) reg0 ; upvar reg($n,1) reg1 ; upvar reg($n,2) reg2 ; upvar reg($n,3) reg3 ; upvar reg($n,4) reg4
		upvar reg($n,5) reg5 ; upvar reg($n,6) reg6 ; upvar reg($n,7) reg7
		puts "DNA (step $step) \n $dna"
		puts "Stack (pointer $aptr) \n $stack"
		puts "Colour $col"
		puts "R0:$reg0 | R1:$reg1 | R2:$reg2 | R3:$reg3 | R4:$reg4 | R5:$reg5 | R6:$reg6 | R7:$reg7"
	}
}
#Start/Stop button
proc startstopbut {} {
	upvar simon simon
	set simon [expr {$simon*-1}]
}
#Add code button, adds code to a random pos
proc addcode {} {
	global scode
	global stacksize
	global cores
	global maxdna
	
	upvar drawlst drawlst
	
	set cell [expr {int(rand()*$cores+1)}]
	
	upvar dna($cell) dna
	upvar stack($cell) stack
	upvar step($cell) step
	upvar col($cell) col
	
	set codefile [open $scode r]
	set contents [read $codefile]
	close $codefile
	set dna $contents
	for {set n [llength $dna]} {$n<$maxdna} {incr n} {lappend dna 0}
	puts $dna
	puts $cell
	
	if {[lsearch $drawlst $cell]==-1} 	{lappend drawlst $cell}
	set col [getcol $dna]
	if {[lindex $dna end]=={}} {set dna [lreplace $dna end end]}	;#saved files often have an extra line, resulting in {} at end of dna code when loaded. This removes that error.
}
#Save simulation
proc savesim {} {
	global astme	;#autosave time
	global ns		;#num steps
	global simname	;#sim name
	global scode	;#most recently inserted code

	#MUTATION CHANCES
	global mutchance
	#REDRAW TIME
	global redrawtme
	#CORE SIZE
	global cores
	#SIM SIZE AND CELL SIZE(PIXELS)
	global simx
	global simy
	global cellx
	global celly
	#STACKSIZE
	global stacksize
	#MAX DNA LENGTH
	global maxdna
	
		set siminfo    "astme $astme \n Step $ns \n Sim $simname \n "
		append siminfo "Mutchance $mutchance \n"
		append siminfo "Redrawtme $redrawtme \n Coresize $cores \n Simx $simx # Simy $simy # CellX $cellx # CellY $celly \n"
		append siminfo "StackSize $stacksize \n MaxDNA $maxdna"

	#Individual cell info
	for {set n 1} {$n<=$cores} {incr n} {
		upvar dna($n) dna
		upvar stack($n) stack
		upvar step($n) step
		upvar col($n) col
		upvar cpu($n) cpu
		upvar reg($n,0) reg0 ; upvar reg($n,1) reg1 ; upvar reg($n,2) reg2 ; upvar reg($n,3) reg3 ; upvar reg($n,4) reg4
		upvar reg($n,5) reg5 ; upvar reg($n,6) reg6 ; upvar reg($n,7) reg7
		upvar aptr($n) aptr
		upvar sptr($n) sptr
		upvar sstp($n) sstp
		append siminfo " \n SCELL$n \n SCellDNA$n $dna ECellDNA$n \n SCellSTACK$n $stack ECellSTACK$n \n "
		append siminfo "Step$n $step # Col$n $col # CPU$n $cpu # \n Reg($n,0) $reg0 # Reg($n,1) $reg1 # Reg($n,2) $reg2 # Reg($n,3) $reg3 # Reg($n,4) $reg4 # "
		append siminfo "Reg($n,5) $reg5 # Reg($n,6) $reg6 # Reg($n,7) $reg7 \n "
		append siminfo "APointer$n $aptr # SPointer$n $sptr # SStep$n $sstp \n ECELL$n"
	}
	set savefile [open "Saved - $simname-Step$ns.de" w]
	puts $savefile $siminfo
	close $savefile
}
proc loadsim {} {
	global simname
	set simfile [open $simname.de r]
	set siminfo [read $simfile]
	close $simfile
	
	upvar astme astme
	upvar ns ns
	upvar simname simname
	upvar scode scode
	#MUTATION CHANCES
	upvar mutchance mutchance
	#REDRAW TIME
	upvar redrawtme redrawtme
	#CORE SIZE								currently set to not change when file loaded
	#upvar cores cores
	#SIM SIZE AND CELL SIZE(PIXELS)
	upvar simx simx
	upvar simy simy
	upvar cellx cellx
	upvar celly celly
	#STACKSIZE
	upvar stacksize stacksize
	#MAX DNA LENGTH
	upvar maxdna maxdna
	
	set astme [lindex $siminfo [expr {[lsearch $siminfo astme]+1}]]
	set ns [lindex $siminfo [expr {[lsearch $siminfo Step]+1}]]
	set simname [lindex $siminfo [expr {[lsearch $siminfo Sim]+1}]]
	
	set mutchance [lindex $siminfo [expr {[lsearch $siminfo Mutchance]+1}]]
	
	set redrawtme [lindex $siminfo [expr {[lsearch $siminfo Redrawtme]+1}]]
	
	set cores [lindex $siminfo [expr {[lsearch $siminfo Coresize]+1}]]
	set simx [lindex $siminfo [expr {[lsearch $siminfo Simx]+1}]]
	set simy [lindex $siminfo [expr {[lsearch $siminfo Simy]+1}]]
	set cellx [lindex $siminfo [expr {[lsearch $siminfo CellX]+1}]]
	set celly [lindex $siminfo [expr {[lsearch $siminfo CellY]+1}]]
	
	set stacksize [lindex $siminfo [expr {[lsearch $siminfo StackSize]+1}]]
	set maxdna [lindex $siminfo [expr {[lsearch $siminfo MaxDNA]+1}]]
	
	#Load cell info: DNA, stack, step, col and cpu.
	upvar drawlst drawlst
	for {set n 1} {$n<=$cores} {incr n} {
		upvar dna($n) dna
		upvar stack($n) stack
		upvar step($n) step
		upvar col($n) cel
		upvar cpu($n) cpu
		upvar reg($n,0) reg0 ; upvar reg($n,1) reg1 ; upvar reg($n,2) reg2 ; upvar reg($n,3) reg3 ; upvar reg($n,4) reg4
		upvar reg($n,5) reg5 ; upvar reg($n,6) reg6 ; upvar reg($n,7) reg7
		upvar aptr($n) aptr
		upvar sptr($n) sptr
		upvar sstp($n) sstp
		set dna [lrange $siminfo [expr {[lsearch $siminfo SCellDNA$n]+1}] [expr {[lsearch $siminfo ECellDNA$n]-1}]]
		set stack [lrange $siminfo [expr {[lsearch $siminfo SCellSTACK$n]+1}] [expr {[lsearch $siminfo ECellSTACK$n]-1}]]
		set step [lindex $siminfo [expr {[lsearch $siminfo Step$n]+1}]]
		set col [lindex $siminfo [expr {[lsearch $siminfo Col$n]+1}]]
		set cpu [lindex $siminfo [expr {[lsearch $siminfo CPU$n]+1}]]
		set reg0 [lindex $siminfo [expr {[lsearch $siminfo Reg($n,0)]+1}]]
		set reg1 [lindex $siminfo [expr {[lsearch $siminfo Reg($n,1)]+1}]]
		set reg2 [lindex $siminfo [expr {[lsearch $siminfo Reg($n,2)]+1}]]
		set reg3 [lindex $siminfo [expr {[lsearch $siminfo Reg($n,3)]+1}]]
		set reg4 [lindex $siminfo [expr {[lsearch $siminfo Reg($n,4)]+1}]]
		set reg5 [lindex $siminfo [expr {[lsearch $siminfo Reg($n,5)]+1}]]
		set reg6 [lindex $siminfo [expr {[lsearch $siminfo Reg($n,6)]+1}]]
		set reg7 [lindex $siminfo [expr {[lsearch $siminfo Reg($n,7)]+1}]]
		set aptr [lindex $siminfo [expr {[lsearch $siminfo APointer$n]+1}]]
		set sptr [lindex $siminfo [expr {[lsearch $siminfo SPointer$n]+1}]]
		set sstp [lindex $siminfo [expr {[lsearch $siminfo SStep$n]+1}]]
		lappend drawlst $n
	}
}
#============================================
#GENERAL USE PROCS
#============================================
proc lcount list {
	foreach x $list {lappend arr($x) {}}
	set res {}
	foreach name [array names arr] {
		lappend res [list $name [llength $arr($name)]]
	}
	return $res
}
#Get a target cell
proc gettarg {y cell} {
	global cores
	set targcell [expr {$cell+$y}]
	while {$targcell>$cores} {set targcell [expr {$targcell-$cores}]}
	while {$targcell<1} {set targcell [expr {$targcell+$cores}]}
	return $targcell
}
#Mass extinction event
proc extinct {x} {
	global cores
	upvar drawlst drawlst
	global maxdna
	set extinctlst ""
	set n [expr {$cores*$x/100}]
	set cell [expr {int(rand()*$cores+1)}]
	for {set x 1} {$x<$n} {incr x} {
		while {[lsearch $extinctlst $cell]!=-1} {set cell [expr {int(rand()*$cores+1)}]}
		upvar dna($cell) dna
		set dna ""
		for {set s 0} {$s<$maxdna} {incr s} {lappend dna 0}
		lappend extinctlst $cell
		if {[lsearch $drawlst $cell]==-1} 	{lappend drawlst $cell}
	}
}
#============================================
#MUTATION PROCS
#============================================
proc mutate {cde} {
	global mutchance
	global DELchance
	global MODchance
	global INSchance
	set rnd [expr {rand()*100}]
	if {$rnd<$mutchance} {
		set cde [rndcom]
		upvar mutcount mutcount
		incr mutcount
		upvar drawlst drawlst
		global cell
		if {[lsearch $drawlst $cell]==-1} 	{lappend drawlst $cell}
	}
	return $cde
}
#rndcom proc - returns a random command number
proc rndcom {} {
	set comm [expr {int(rand()*32)}]
	return $comm
}
#============================================
#REDRAW PROCS
#============================================
proc redraw {} {
	upvar drawlst drawlst
	foreach cell $drawlst {
		upvar dna($cell) dna
		upvar col($cell) col
		set col [getcol $dna]
		if {[.universe itemcget cell($cell) -fill]!=$col} {
			.universe itemconfigure cell($cell) -fill $col
		}
	}
	set drawlst ""
}
proc getcol {dna} {
	global maxdna
	#get rgb for each command in dna
	set r1 0;set g1 0;set b1 0
	foreach cde $dna {
	#	METHOD 1: SLOWER, MORE ACCURATE
	#	if {$cde==0x00} {incr r 1	;incr g 2	;incr b 7};	if {$cde==0x01} {incr r 1	;incr g 2	;incr b 7}
		
	#	if {$cde==0x02} {incr r 1	;incr g 8	;incr b 1};	if {$cde==0x03} {incr r 1	;incr g 8	;incr b 1}
	#	if {$cde==0x04} {incr r 1	;incr g 8	;incr b 1}
		
	#	if {$cde==0x05} {incr r 3	;incr g 7	;incr b 0};	if {$cde==0x06} {incr r 3	;incr g 7	;incr b 0}
	#	if {$cde==0x07} {incr r 3	;incr g 7	;incr b 0};	if {$cde==0x08} {incr r 3	;incr g 7	;incr b 0}
		
	#	if {$cde==0x09} {incr r 0	;incr g 7	;incr b 3};	if {$cde==0x0a} {incr r 0	;incr g 7	;incr b 3}
	#	if {$cde==0x0b} {incr r 0	;incr g 7	;incr b 3}
		
	#	if {$cde==0x0c} {incr r 0	;incr g 5	;incr b 5};	if {$cde==0x0d} {incr r 0	;incr g 5	;incr b 5}
		
	#	if {$cde==0x0e} {incr r 3	;incr g 5	;incr b 2};	if {$cde==0x0f} {incr r 3	;incr g 5	;incr b 2}
		
	#	if {$cde==0x10} {incr r 1	;incr g 1	;incr b 8};	if {$cde==0x11} {incr r 1	;incr g 1	;incr b 8}
		
	#	if {$cde==0x12} {incr r 3	;incr g 3	;incr b 4};	if {$cde==0x13} {incr r 3	;incr g 3	;incr b 4}
		
	#	if {$cde==0x14} {incr r 2	;incr g 6	;incr b 2};	if {$cde==0x15} {incr r 2	;incr g 6	;incr b 2}
		
	#	if {$cde==0x16} {incr r 6	;incr g 2	;incr b 2};	if {$cde==0x17} {incr r 6	;incr g 2	;incr b 2}
		
	#	if {$cde==0x18} {incr r 3	;incr g 4	;incr b 3}
		
	#	if {$cde==0x19} {incr r 9	;incr g 1	;incr b 0};	if {$cde==0x1a} {incr r 8	;incr g 1	;incr b 1}
		
	#	if {$cde==0x1b} {incr r 0	;incr g 0	;incr b 0};	if {$cde==0x1c} {incr r 0	;incr g 0	;incr b 0}
	#	if {$cde==0x1d} {incr r 0	;incr g 0	;incr b 0};	if {$cde==0x1e} {incr r 0	;incr g 0	;incr b 0}
	#	if {$cde==0x1f} {incr r 0	;incr g 0	;incr b 0}
	
	#	METHOD 2: FASTER, LESS ACCURATE
		if {$cde>0x01 && $cde<=0x09} {incr r1 1}
		if {$cde>0x09 && $cde<=0x11} {incr g1 1}
		if {$cde>0x11 && $cde<=0x19} {incr b1 1}
	}
	#Get sum of rgb, then multiply it out to make sum of rgb=length dna*2
	#set tcol [expr {$r+$g+$b+0.01}]
	#set maxcol [expr {[llength $dna]*2}]
	#set factor [expr {$maxcol/$tcol}]
	
	#set r1 [expr {int($r*$factor)}]
	#set g1 [expr {int($g*$factor)}]
	#set b1 [expr {int($b*$factor)}]
	#set to hex
	set r [format %x [expr {int(($r1>255 ? 255:$r1))}]]
		if {[string length $r]<2} {set r 0$r}
		if {[string length $r]>2} {set r ff}
	set g [format %x [expr {int(($g1>255 ? 255:$g1))}]]
		if {[string length $g]<2} {set g 0$g}
		if {[string length $g]>2} {set g ff}
	set b [format %x [expr {int(($b1>255 ? 255:$b1))}]]
		if {[string length $b]<2} {set b 0$b}
		if {[string length $b]>2} {set b ff}
	#set ncol (new colour) as formatted colour
	set ncol #$r$g$b
	return $ncol
}
proc getcom {n} {
	set com $n
	if {$n==0} {set com nop0}	; if {$n==1} {set com nop1}
	
	if {$n==2} {set com and}	; if {$n==3} {set com or}	; if {$n==4} {set com xor}
	
	if {$n==5} {set com add}	; if {$n==6} {set com sub}
	if {$n==7} {set com mul}	; if {$n==8} {set com div}
	
	if {$n==9} {set com more}	; if {$n==10} {set com less}; if {$n==11} {set com equal}
	
	if {$n==12} {set com setr}	; if {$n==13} {set com readr}
	if {$n==14} {set com shr}	; if {$n==15} {set com shl}
	if {$n==16} {set com call}	; if {$n==17} {set com ret}
	if {$n==18} {set com mpr}	; if {$n==19} {set com mpl}
	if {$n==20} {set com inc}	; if {$n==21} {set com dec}
	if {$n==22} {set com codel}	; if {$n==23} {set com readc}
	if {$n==24} {set com zero}
	if {$n==25} {set com move}	; if {$n==26} {set com $n}
	if {$n==27} {set com $n}	; if {$n==28} {set com $n}
	if {$n==29} {set com $n}	; if {$n==30} {set com $n}
	if {$n==31} {set com $n}
	return $com
}
proc convert {dna} {
	set ndna ""
	foreach cde $dna {
		lappend ndna [getcom $cde]
	}
	return $ndna
}
#============================================
#VARIABLES FOR EACH CELL
#============================================
#LISTS:
#======
#dna($cell)			- code of cell
#stack($cell)		- datastack
#VARIABLES:
#==========
#step($cell)		- step in DNA org is on
#col($cell)			- colour of cell
#cpu($cell)			- cpu time for cell
#reg($cell,(0-7))	- registers 0-9
#aptr($cell)		- active pointer on stack
#sptr($cell)		- stored pointer
#sstp($cell)		- stored step
#============================================
#COMMANDS
#============================================
#Stack (0=aptr)
#ID		0	1	2
#00	:	-	-	-	nop0	pattern of 4 of these marker for call
#01	:	-	-	-	nop1	pattern of 4 of these marker for call
#02	:	x	y	-	and		x=x&y							BOOLEAN LOGIC
#03	:	x	y	-	or		x=x|y
#04	:	x	y	-	xor		x=x^y							<
#05	:	x	y	-	add		x=x+y							ARITHIMETIC
#06	:	x	y	-	sub		x=x-y
#07	:	x	y	-	mul		x=x*y
#08	:	x	y	-	div		x=x/y							<
#09	:	x	y	-	more	x=x>y							LOGICAL COMPARISONS
#0A	:	x	y	-	less	x=x<y
#0B	:	x	y	-	equal	x=x==y							<
#0C	:	x	y	-	setr	R(x)=y							REGISTER OPERATIONS
#0D	:	x	-	-	readr	x=R(x)							<
#0E	:	x	-	-	shr		x=x>>1 (x=x/2)(rounded down)	BIT SHIFT
#0F	:	x	-	-	shl		x=x<<1 (x=x*2)					<
#10	:	x	y	-	call	step=#y & sstp=step if x!=0		CALL
#11	:	-	-	-	ret		step=sstp						<
#12	:	-	-	-	mpr		incr aptr						POINTER
#13	:	-	-	-	mpl		decr aptr						<
#14	:	x	-	-	inc		incr x							INTEGER
#15	:	x	-	-	dec		decr x							<
#16	:	x	-	-	codel	x=llength[dna(cell+x)]
#17	:	x	y	-	readc	x=lindex dna(cell+y) x
#18	:	-	-	-	zero	zero all stack
#19	:	x	y	z	move	copy x to position z of dna(cell+y)
#1A	:	-	-	-	
#1B	:	-	-	-	
#1C	:	-	-	-	
#1D	:	-	-	-	
#1E	:	-	-	-	
#1F	:	-	-	-	
#============================================
#CODE COMMANDS
#============================================
proc and {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {$x&$y}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc or {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {$x|$y}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc xor {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {$x^$y}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
#============================================
proc add {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {($x+$y)&255}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc sub {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {($x-$y)&255}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc mul {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {($x*$y)&255}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc div {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	if {$y==0} {set y 1}
	lset stack $aptr [expr {($x/$y)&255}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
#============================================
proc more {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {$x>$y}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc less {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {$x<$y}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc equal {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {$x==$y}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
#============================================
proc setr {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	set x [expr {$x&7}]
	upvar reg($cell,$x) reg
	set reg $y
	lset stack $aptr 0
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc readr {} {
	global cell
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set x [expr {$x&7}]
	upvar reg($cell,$x) reg
	lset stack $aptr $reg
}

#============================================
proc shr {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {($x>>$y)&255}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc shl {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	lset stack $aptr [expr {($x<<$y)&255}]
	lset stack [expr {($aptr+1)&$stacksize}] 0
}

#============================================
proc call {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	upvar step($cell) step
	upvar sstp($cell) sstp
	upvar dna($cell) dna
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	set x [expr {$x&15}]
	if {$y!=0} {
		#x=4 bit decimal format number
		#dna=list containing decimal numbers 0-31
		#this will leave variable $step holding the position of the pattern in the code.
		#nop0-3 each hold either a 0 or 1, based on what x was
		#returns a bits string, e.g. 10 => 1010
		binary scan [binary format I1 $x] B* x
		#Find pattern of 4 nop's (commands 0 & 1) matching bits string
		set nop0 [expr {[string index $x 28]==1}]
		set nop1 [expr {[string index $x 29]==1}]
		set nop2 [expr {[string index $x 30]==1}]
		set nop3 [expr {[string index $x 31]==1}]
		set curstep 0
		set sstp $step
		while {[lsearch -start $curstep $dna $nop0]!=-1} {
			set nop0pos [lsearch -start $curstep $dna $nop0]
			if {[lindex $dna [expr {$nop0pos+1}]]==$nop1 && \
				[lindex $dna [expr {$nop0pos+2}]]==$nop2 && \
				[lindex $dna [expr {$nop0pos+3}]]==$nop3} {set step [expr {$nop0pos+3}] ; break}
			set curstep [expr {$nop0pos+1}]
		}
	}
	lset stack $aptr 0
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc ret {} {
	global cell
	upvar step($cell) step
	upvar sstp($cell) sstp
	set step $sstp
}
#============================================
proc mpr {} {
	global cell
	global stacksize
	upvar aptr($cell) aptr
	incr aptr
	set aptr [expr {$aptr&$stacksize}]
}
proc mpl {} {
	global cell
	global stacksize
	upvar aptr($cell) aptr
	incr aptr -1
	set aptr [expr {$aptr&$stacksize}]
}

#============================================
proc inc {} {
	global cell
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	lset stack $aptr [expr {([lindex $stack $aptr]+1)&255}]
}
proc dec {} {
	global cell
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	lset stack $aptr [expr {([lindex $stack $aptr]-1)&255}]
}

#============================================
proc codel {} {
	global cell
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set targ [gettarg $x $cell]
	upvar dna($targ) dna
	lset stack $aptr [expr {[llength $dna]&255}]
}
proc readc {} {
	global maxdna
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	set x [expr {$x&$maxdna}]
	set targ [gettarg $y $cell]
	upvar dna($targ) dna
	if {$x>([llength $dna]-1)} {set x [expr {[llength $dna]-1}]}
	set com [lindex $dna $x]
	if {$com=={}} {set com 0}
	lset stack $aptr $com
	lset stack [expr {($aptr+1)&$stacksize}] 0
}
proc zero {} {
	global cell
	global stacksize
	upvar stack($cell) stack
	set stack ""
	for {set n 0} {$n<=$stacksize} {incr n} {
		lappend stack 0
	}
}
proc move {} {
	global maxdna
	global cell
	global stacksize
	upvar stack($cell) stack
	upvar aptr($cell) aptr
	set x [lindex $stack $aptr]
	set y [lindex $stack [expr {($aptr+1)&$stacksize}]]
	set z [lindex $stack [expr {($aptr+2)&$stacksize}]]
	set x [expr {$x&31}]
	set z [expr {$z&$maxdna}]
	if {$z==$maxdna} {incr z -1}
	set targ [gettarg $y $cell]
	upvar dna($targ) dna
	lset dna $z $x
	upvar drawlst drawlst
	if {[lsearch $drawlst $targ]==-1} 	{lappend drawlst $targ}
	lset stack $aptr 0
	lset stack [expr {($aptr+1)&$stacksize}] 0
	lset stack [expr {($aptr+2)&$stacksize}] 0
}
#============================================
#MAIN LOOP
#============================================
while {1} {
	while {$simon==1} {
					for {set cell 1} {$cell<$cores} {incr cell} {
						set cde [lindex $dna($cell) $step($cell)]
						#Mutate
						set cde [mutate $cde]
						
						if {$cde==0x00} {}      ; if {$cde==0x01} {}   ;#nop commands
						
						if {$cde==0x02} {and}   ; if {$cde==0x03} {or} ; if {$cde==0x04} {xor}
						
						if {$cde==0x05} {add}   ; if {$cde==0x06} {sub}
						if {$cde==0x07} {mul}   ; if {$cde==0x08} {div}
						
						if {$cde==0x09} {more}  ; if {$cde==0x0a} {less} ; if {$cde==0x0b} {equal}
						
						if {$cde==0x0c} {setr}  ; if {$cde==0x0d} {readr}
						if {$cde==0x0e} {shr}   ; if {$cde==0x0f} {shl}
						if {$cde==0x10} {call}  ; if {$cde==0x11} {ret}
						if {$cde==0x12} {mpr} 	; if {$cde==0x13} {mpl}
						if {$cde==0x14} {inc} 	; if {$cde==0x15} {dec}
						if {$cde==0x16} {codel} ; if {$cde==0x17} {readc}
						if {$cde==0x18} {zero}
						if {$cde==0x19} {move}  ; if {$cde==0x1a} {}
						if {$cde==0x1b} {}
						if {$cde==0x1c} {}
						if {$cde==0x1d} {}
						if {$cde==0x1e} {}
						if {$cde==0x1f} {}
						#============================================
						#Debugging options
						#============================================
						if {$debug==1} {
							puts "Cell:$cell | CPU:$cpu($cell) | Command:[getcom $cde] | Step:$step($cell) | APtr:$aptr($cell) \n Stack:$stack($cell)"
							puts "Registers:$reg($cell,0)|$reg($cell,1)|$reg($cell,2)|$reg($cell,3)|$reg($cell,4)|$reg($cell,5)|$reg($cell,6)|$reg($cell,7) \n"
							after $debugtme {set sleep {}}
							tkwait variable sleep
						}
						#Inc step
						incr step($cell)
						set step($cell) [expr {$step($cell)&$maxdna}]
					}
			incr ns
			set nslab "Step $ns"
			#Save cell/sim
			if {$ns%$astme==0} {redraw;savesim}
		
		after 1 {set sleep {}}
		tkwait variable sleep
		
		if {$ns%$redrawtme==0} {redraw}
	}
	after 1 {set sleep {}}
	tkwait variable sleep
}