###############################################################################
#
#  Makefile
#
#  Various targets for utility programs to perform pre-processing
#  and post-processing tasks.
#
#  Note all the builds are parallel, but the utilities are
#  intended to be run in serial.
#
#  Edinburgh Soft Matter and Statistical Physics Group and
#  Edinburgh Parallel Computing Centre
#
#  (c) 2016-2019 The University of Edinburgh
#
#  Contributing authors:
#  Kevin Stratford (kevin@epcc.ed.ac.uk)
#
###############################################################################

include ../Makefile.mk

# Compilation etc

SRC  = $(ROOT_DIR)./src
INCL = -I$(SRC) $(TARGET_INC_PATH) $(MPI_INC_PATH)

BLIBS = $(MPI_LIB_PATH) $(MPI_LIB) $(TARGET_LIB_PATH) $(TARGET_LIB)
LIBS  = $(SRC)/libludwig.a ${BLIBS} -lm


default:
	$(MAKE) build

build:
	$(MAKE) extract
	$(MAKE) capillary
	$(MAKE) colloid_init
	$(MAKE) extract_colloids

colloid_init: colloid_init.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)

extract_colloids: extract_colloids.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)

capillary: capillary.o
	$(CC) $(LDFLAGS) -o $@ $^ -lm

extract: extract.o
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)


# Default rules

.PHONY : clean
clean:
	rm -f *.o colloid_init extract_colloids capillary extract


.SUFFIXES:
.SUFFIXES: .c .o

.c.o:
	$(CC) $(CFLAGS) $(INCL) -c $*.c

