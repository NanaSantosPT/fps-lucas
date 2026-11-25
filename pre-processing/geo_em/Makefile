# ===== Makefile for WRF_LUCAS_PFTs_v3_water_ice_landmask =====
# Strategy:
# 1) Use nf-config (netcdf-fortran) to get include/libs (best)
# 2) Fallback to known Miniforge3 paths from your cluster
# 3) Add rpath so the runtime finds the right shared libs without module juggling

# --- Compiler ---
FC = gfortran
FFLAGS_OPT ?= -O2
FFLAGS_MISC ?= -ffree-line-length-none -Wno-tabs

# --- Try to detect nf-config / nc-config ---
NF_CONFIG ?= /home/apps/others/miniforge3/bin/nf-config
NC_CONFIG ?= nc-config

# --- Query flags from nf-config if available ---
# (Some nf-config builds don't support --all, but do support --fflags/--flibs)
ifeq ($(shell test -x $(NF_CONFIG) && echo yes),yes)
  INC_NF   := $(shell $(NF_CONFIG) --fflags 2>/dev/null)
  LIBS_NF  := $(shell $(NF_CONFIG) --flibs  2>/dev/null)
else
  # Fallback: paths from your cluster’s Miniforge3 (from nc-config --all)
  INC_NF   := -I/home/apps/others/miniforge3/include
  LIBS_NF  := -L/home/apps/others/miniforge3/lib -lnetcdff -lnetcdf
endif

# --- Optional: prefer Miniforge libs at runtime (avoid mixing with module netcdf) ---
RPATH ?= -Wl,-rpath,/home/apps/others/miniforge3/lib

# --- Final flags ---
FCFLAGS = $(FFLAGS_OPT) $(FFLAGS_MISC) $(INC_NF)
LDFLAGS = $(LIBS_NF) $(RPATH)

# --- Program(s) ---
PROGRAMS = WRF_LUCAS_PFTs_v3_water_ice_landmask

all: $(PROGRAMS)

%: %.o
	$(FC) $(FCFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.f90
	$(FC) $(FCFLAGS) -c $<

.PHONY: clean veryclean
clean:
	rm -f *.o *.mod *.MOD *_genmod.f90 tmpfile* log
veryclean: clean
	rm -f $(PROGRAMS) *~

