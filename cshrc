# Note: This cshrc is for client

# Date:        25/Aug/2025

setenv LM_LICENSE_FILE 5280@cadenceserver
setenv CDS_LIC_FILE $LM_LICENSE_FILE
setenv CDC_INST_DIR /mnt/cadence_tools/installs

setenv CDS_Netlisting_Mode Analog
setenv LANG C

setenv LD_LIBRARY_PATH

echo "*************************************"
echo "Welcome to Cadence Tools Suite"
echo "*************************************"
echo "Following tools are available:"

############################################
#####		Assura  	       #####
############################################



############################################
#####		XCELIUM		       #####
############################################
setenv XLCHOME $CDC_INST_DIR/XCELIUM2309
setenv PATH {$PATH}:$XLCHOME/bin:$XLCHOME/tools/bin
echo $XLCHOME

############################################
############################################
#####		JASPER		       #####
############################################
setenv JASP $CDC_INST_DIR/JASPER25
setenv PATH {$PATH}:$JASP/bin
echo $JASP

