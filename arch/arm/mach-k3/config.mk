# SPDX-License-Identifier:	GPL-2.0+
#
# Copyright (C) 2017-2018 Texas Instruments Incorporated - http://www.ti.com/
#	Lokesh Vutla <lokeshvutla@ti.com>

ifdef CONFIG_SPL_BUILD

# Openssl is required to generate x509 certificate.
# Error out if openssl is not available.
ifeq ($(shell which openssl),)
$(error "No openssl in $(PATH), consider installing openssl")
endif

IMAGE_SIZE= $(shell cat $(obj)/u-boot-spl.bin | wc -c)
MAX_SIZE= $(shell printf "%d" $(CONFIG_SYS_K3_MAX_DOWNLODABLE_IMAGE_SIZE))

ifeq ($(CONFIG_SYS_K3_KEY), "")
KEY=""
# On HS use real key or warn if not available
ifeq ($(CONFIG_TI_SECURE_DEVICE),y)
ifneq ($(wildcard $(TI_SECURE_DEV_PKG)/keys/custMpk.pem),)
KEY=$(TI_SECURE_DEV_PKG)/keys/custMpk.pem
else
$(warning "WARNING: signing key not found. Random key will NOT work on HS hardware!")
endif
endif
else
KEY=$(patsubst "%",$(srctree)/%,$(CONFIG_SYS_K3_KEY))
endif

# X509 SWRV default
SWRV = $(CONFIG_K3_X509_SWRV)
# On HS use SECDEV provided software revision or warn if not available
ifeq ($(CONFIG_TI_SECURE_DEVICE),y)
ifneq ($(wildcard $(TI_SECURE_DEV_PKG)/keys/swrv.txt),)
SWRV= $(shell cat $(TI_SECURE_DEV_PKG)/keys/swrv.txt)
else
$(warning "WARNING: Software revision file not found. Default may not work on HS hardware.")
endif
endif

# tiboot3.bin is mandated by ROM and ROM only supports R5 boot.
# So restrict tiboot3.bin creation for CPU_V7R.
ifdef CONFIG_CPU_V7R
image_check: $(obj)/u-boot-spl.bin FORCE
	@if [ $(IMAGE_SIZE) -gt $(MAX_SIZE) ]; then			    \
		echo "===============================================" >&2; \
		echo "ERROR: Final Image too big. " >&2;		    \
		echo "$< size = $(IMAGE_SIZE), max size = $(MAX_SIZE)" >&2; \
		echo "===============================================" >&2; \
		exit 1;							    \
	fi

tiboot3.bin: image_check FORCE
	$(srctree)/tools/k3_gen_x509_cert.sh -c 16 -b $(obj)/u-boot-spl.bin \
				-o $@ -l $(CONFIG_SPL_TEXT_BASE) -r $(SWRV) -k $(KEY)

INPUTS-y	+= tiboot3.bin
endif

ifdef CONFIG_ARM64

ifeq ($(CONFIG_SOC_K3_J721E),)
export DM := /dev/null
endif

ifeq ($(CONFIG_TI_SECURE_DEVICE),y)
SPL_ITS := u-boot-spl-k3_HS.its
$(SPL_ITS): export IS_HS=1
INPUTS-y	+= tispl.bin_HS
INPUTS-y	+= tispl.bin
tispl.bin: $(obj)/u-boot-spl-nodtb.bin_HS $(patsubst %,$(obj)/dts/%.dtb_HS,$(subst ",,$(CONFIG_SPL_OF_LIST)))
else
SPL_ITS := u-boot-spl-k3.its
INPUTS-y	+= tispl.bin
endif

ifeq ($(CONFIG_SPL_OF_LIST),)
LIST_OF_DTB := $(CONFIG_DEFAULT_DEVICE_TREE)
else
LIST_OF_DTB := $(CONFIG_SPL_OF_LIST)
endif

quiet_cmd_k3_mkits = MKITS   $@
cmd_k3_mkits = \
	$(srctree)/tools/k3_fit_atf.sh \
	$(CONFIG_K3_ATF_LOAD_ADDR) \
	$(patsubst %,$(obj)/dts/%.dtb,$(subst ",,$(LIST_OF_DTB))) > $@

$(SPL_ITS): FORCE
	$(call cmd,k3_mkits)
endif

else

ifeq ($(CONFIG_TI_SECURE_DEVICE),y)
INPUTS-y	+= u-boot.img_HS
else
INPUTS-y	+= u-boot.img
endif
endif

include $(srctree)/arch/arm/mach-k3/config_secure.mk
