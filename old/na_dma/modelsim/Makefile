#
#	Makefile for ModelSim simulation
#


NOCDIR=../src
#OPTIONS=-93 -quiet -check_synthesis -lint -pedanticerrors
OPTIONS=-93 -quiet

ifeq ($(WINDIR),)
	S=:
else
	S=\;
endif

# Use Wine on OSX
# I would like to use a better way, but some shell variables
# are not set within make.... Don't know why...
ifeq ($(TERM_PROGRAM),Apple_Terminal)
	WINE=wine
else
	WINE=
endif


all: clean base
	$(WINE) vcom $(OPTIONS) $(NOCDIR)/top3.vhd
	$(WINE) vsim -do sim.do top3

base:
	$(WINE) vlib work
	$(WINE) vcom $(OPTIONS) $(NOCDIR)/defs.vhd
	$(WINE) vcom $(OPTIONS) $(NOCDIR)/bram.vhd
	$(WINE) vcom $(OPTIONS) $(NOCDIR)/bram_tdp.vhd
	$(WINE) vcom $(OPTIONS) $(NOCDIR)/counter.vhd
	$(WINE) vcom $(OPTIONS) $(NOCDIR)/dma.vhd
	$(WINE) vcom $(OPTIONS) $(NOCDIR)/nAdapter.vhd


clean:
	-rm -f transcript
	-rm -f *.wlf
	-rm -rf work
