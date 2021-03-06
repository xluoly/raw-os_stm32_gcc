# ARM Cortex-Mx common makefile scripts and rules.

##############################################################################
# Processing options coming from the upper Makefile.
#

# Compiler options
OPT = $(USE_OPT)
COPT = $(USE_COPT)
CPPOPT = $(USE_CPPOPT)

# Garbage collection
  OPT   += -ffunction-sections -fdata-sections -fno-common
  LDOPT := ,--gc-sections

# Linker extra options
ifneq ($(USE_LDOPT),)
  LDOPT := $(LDOPT),$(USE_LDOPT)
endif

# Link time optimizations
ifeq ($(USE_LTO),yes)
  OPT += -flto
endif

# FPU-related options
ifeq ($(USE_FPU),)
  USE_FPU = no
endif
ifneq ($(USE_FPU),no)
  OPT    += -mfloat-abi=$(USE_FPU) -mfpu=fpv4-sp-d16 -fsingle-precision-constant
  DDEFS  += -DCORTEX_USE_FPU=TRUE
  DADEFS += -DCORTEX_USE_FPU=TRUE
else
  DDEFS  += -DCORTEX_USE_FPU=FALSE
  DADEFS += -DCORTEX_USE_FPU=FALSE
endif

# Output directory and files
ifeq ($(BUILDDIR),)
  BUILDDIR = build
endif
ifeq ($(BUILDDIR),.)
  BUILDDIR = build
endif
OUTFILES = $(BUILDDIR)/$(PROJECT).elf \
           $(BUILDDIR)/$(PROJECT).hex \
           $(BUILDDIR)/$(PROJECT).bin \
           $(BUILDDIR)/$(PROJECT).dmp

ifdef SREC
OUTFILES += $(BUILDDIR)/$(PROJECT).srec
endif

# Source files groups and paths
ifeq ($(USE_THUMB),yes)
  TCSRC   += $(CSRC)
  TCPPSRC += $(CPPSRC)
else
  ACSRC   += $(CSRC)
  ACPPSRC += $(CPPSRC)
endif
ASRC	  = $(ACSRC)$(ACPPSRC)
TSRC	  = $(TCSRC)$(TCPPSRC)
SRCPATHS  = $(sort $(dir $(ASMXSRC)) $(dir $(ASMSRC)) $(dir $(ASRC)) $(dir $(TSRC)))

# Various directories
OBJDIR    = $(BUILDDIR)/obj

# Object files groups
ACOBJS    = $(addprefix $(OBJDIR)/, $(ACSRC:.c=.o))
ACPPOBJS  = $(addprefix $(OBJDIR)/, $(ACPPSRC:.cpp=.o))
TCOBJS    = $(addprefix $(OBJDIR)/, $(TCSRC:.c=.o))
TCPPOBJS  = $(addprefix $(OBJDIR)/, $(TCPPSRC:.cpp=.o))
ASMOBJS   = $(addprefix $(OBJDIR)/, $(ASMSRC:.s=.o))
ASMXOBJS  = $(addprefix $(OBJDIR)/, $(ASMXSRC:.S=.o))
OBJS	  = $(ASMXOBJS) $(ASMOBJS) $(ACOBJS) $(TCOBJS) $(ACPPOBJS) $(TCPPOBJS)
DEPS      = $(OBJS:.o=.d)

# Paths
IINCDIR   = $(patsubst %,-I%,$(INCDIR) $(DINCDIR) $(UINCDIR))
LLIBDIR   = $(patsubst %,-L%,$(DLIBDIR) $(ULIBDIR))

# Macros
DEFS      = $(DDEFS) $(UDEFS)
ADEFS 	  = $(DADEFS) $(UADEFS)

# Libs
LIBS      = $(DLIBS) $(ULIBS)

# Various settings
MCFLAGS   = -mcpu=$(MCU)
ODFLAGS	  = -x --syms
ASFLAGS   = $(MCFLAGS) -Wa,-amhls=$(@:.o=.lst) $(ADEFS)
ASXFLAGS  = $(MCFLAGS) -Wa,-amhls=$(@:.o=.lst) $(ADEFS)
CFLAGS    = $(MCFLAGS) $(OPT) $(COPT) $(CWARN) -Wa,-alms=$(@:.o=.lst) $(DEFS)
CPPFLAGS  = $(MCFLAGS) $(OPT) $(CPPOPT) $(CPPWARN) -Wa,-alms=$(@:.o=.lst) $(DEFS)
LDFLAGS   = $(MCFLAGS) $(OPT) -nostartfiles $(LLIBDIR) -Wl,-Map=$(BUILDDIR)/$(PROJECT).map,--cref,--no-warn-mismatch,--library-path=$(RULESPATH),--script=$(LDSCRIPT)$(LDOPT)

# Thumb interwork enabled only if needed because it kills performance.
ifneq ($(TSRC),)
  CFLAGS   += -DTHUMB_PRESENT
  CPPFLAGS += -DTHUMB_PRESENT
  ASFLAGS  += -DTHUMB_PRESENT
  ifneq ($(ASRC),)
    # Mixed ARM and THUMB mode.
    CFLAGS   += -mthumb-interwork
    CPPFLAGS += -mthumb-interwork
    ASFLAGS  += -mthumb-interwork
    LDFLAGS  += -mthumb-interwork
  else
    # Pure THUMB mode, THUMB C code cannot be called by ARM asm code directly.
    CFLAGS   += -mno-thumb-interwork -DTHUMB_NO_INTERWORKING
    CPPFLAGS += -mno-thumb-interwork -DTHUMB_NO_INTERWORKING
    ASFLAGS  += -mno-thumb-interwork -DTHUMB_NO_INTERWORKING -mthumb
    LDFLAGS  += -mno-thumb-interwork -mthumb
  endif
else
  # Pure ARM mode
  CFLAGS   += -mno-thumb-interwork
  CPPFLAGS += -mno-thumb-interwork
  ASFLAGS  += -mno-thumb-interwork
  LDFLAGS  += -mno-thumb-interwork
endif

# Generate dependency information
ASFLAGS  += -MD -MP -MF $(@:.o=.d)
ASXFLAGS += -MD -MP -MF $(@:.o=.d)
CFLAGS   += -MD -MP -MF $(@:.o=.d)
CPPFLAGS += -MD -MP -MF $(@:.o=.d)

# Paths where to search for sources
#VPATH     = $(SRCPATHS)

#
# Makefile rules
#

all: $(OBJS) $(OUTFILES) MAKE_ALL_RULE_HOOK

MAKE_ALL_RULE_HOOK:

$(OBJS): | $(BUILDDIR)

$(BUILDDIR) $(OBJDIR):
	mkdir -p $(OBJDIR)

$(ACPPOBJS) : $(OBJDIR)/%.o : %.cpp Makefile
	@mkdir -p $(dir $@)
	@echo
	@echo Compiling $<
	$(CPPC) -c $(CPPFLAGS) $(AOPT) -I. $(IINCDIR) $< -o $@

$(TCPPOBJS) : $(OBJDIR)/%.o : %.cpp Makefile
	@mkdir -p $(dir $@)
	@echo
	@echo Compiling $<
	$(CPPC) -c $(CPPFLAGS) $(TOPT) -I. $(IINCDIR) $< -o $@

$(ACOBJS) : $(OBJDIR)/%.o : %.c Makefile
	@mkdir -p $(dir $@)
	@echo
	@echo Compiling $<
	$(CC) -c $(CFLAGS) $(AOPT) -I. $(IINCDIR) $< -o $@

$(TCOBJS) : $(OBJDIR)/%.o : %.c Makefile
	@mkdir -p $(dir $@)
	@echo
	@echo Compiling $<
	$(CC) -c $(CFLAGS) $(TOPT) -I. $(IINCDIR) $< -o $@

$(ASMOBJS) : $(OBJDIR)/%.o : %.s Makefile
	@mkdir -p $(dir $@)
	@echo
	@echo Compiling $<
	$(AS) -c $(ASFLAGS) -I. $(IINCDIR) $< -o $@

$(ASMXOBJS) : $(OBJDIR)/%.o : %.S Makefile
	@mkdir -p $(dir $@)
	@echo
	@echo Compiling $<
	$(CC) -c $(ASXFLAGS) $(TOPT) -I. $(IINCDIR) $< -o $@

%.elf: $(OBJS) $(LDSCRIPT)
	@echo
	@echo Linking $@
	$(LD) $(OBJS) $(LDFLAGS) $(LIBS) -o $@

%.hex: %.elf $(LDSCRIPT)
	@echo
	@echo Creating $@
	$(HEX) $< $@

%.bin: %.elf $(LDSCRIPT)
	@echo
	@echo Creating $@
	$(BIN) $< $@

%.srec: %.elf $(LDSCRIPT)
	@echo
	@echo Creating $@
	$(SREC) $< $@

%.dmp: %.elf $(LDSCRIPT)
	@echo
	@echo Creating $@
	$(OD) $(ODFLAGS) $< > $@
	@echo
	@$(SZ) $<
	@echo
	@echo Done

lib: $(OBJS) $(BUILDDIR)/lib$(PROJECT).a

$(BUILDDIR)/lib$(PROJECT).a: $(OBJS)
	@$(AR) -r $@ $^
	@echo
	@echo Done

clean:
	@echo Cleaning
	-rm -fR $(BUILDDIR)
	@echo Done

#
# Include the dependency files, should be the last of the makefile
#
-include $(OBJS:.o=.d)

# *** EOF ***
