#############################################################################
# UI descriptions
#############################################################################
# Setting for Synthesis Configuration
source "[ ui::getModelPath ]/createDivideParam.tcl"

proc addMySynOption {} {
ui::addSynOption -t "set_option -vlog_std v2001"
ui::addSynOption -t "set_option -disable_io_insertion 1"
}

#add Pin

proc AddSymbolPins {} {

    global pin_show_CS_n_EN
    global pin_show_DEBUG_EN

    global pin_show_a_MEM_BANK_WIDTH
    global pin_show_a_MEM_DQS_WIDTH
    global pin_show_a_MEM_DM_WIDTH
    global pin_show_a_MEM_DQ_WIDTH
    global pin_show_a_CTRL_ADDR_WIDTH
    global pin_show_a_MEM_ROW_WIDTH

    global pin_show_b_MEM_DQS_WIDTH
    global pin_show_b_MEM_DQ_WIDTH

    global fix_pin_show_b_MEM_DQS_WIDTH
    global fix_pin_show_b_MEM_DQ_WIDTH


    set path_ip [ui::getModelPath]
    set pins_in_file [open $path_ip/ipsxb_ddr_top_v1_4_wrapper.v.xml r]

    set start_line 56
    set line_cnt 0
    set show_switch_list [list ]

    while {[gets $pins_in_file file_line] > -1} {
        if {$line_cnt > $start_line} {
            # io instantiation end
            if {[regexp {^\ *\)\ *;} $file_line]} {
                break
            # single bit io.
            } elseif {[regexp {^\ *(input|output|inout)\ *([a-z0-9_]+)} $file_line match_string io_dir io_name]} {
                ui::addPin -dir $io_dir  -name $io_name  -text "$io_name"
                foreach show_name $show_switch_list { lappend $show_name $io_name }
            # muti bit io, fixed width.
            } elseif {[regexp {^\ *(input|output|inout)\ *\[\ *([0-9]+)\ *:\ *0\ *\]\ *([a-z0-9_]+)} $file_line match_string io_dir io_width io_name]} {
                ui::addPin -dir $io_dir  -name $io_name -bus -msb $io_width -text "$io_name"
                foreach show_name $show_switch_list { lappend $show_name $io_name }
            # muti bit io, variable width.
            } elseif {[regexp {^\ *(input|output|inout)\ *\[\ *([A-Z_]+)\ *-\ *1\ *:\ *0\ *\]\ *([a-z0-9_]+)} $file_line match_string io_dir io_width io_name]} {
                ui::addPin -dir $io_dir  -name $io_name -bus -msb [expr [ui::getValue -name "$io_width"] - 1] -text "$io_name"
                foreach show_name $show_switch_list { lappend $show_name $io_name }
                lappend "pin_show_a_$io_width" $io_name
            # muti bit io, variable width, n*WIDTH.
            } elseif {[regexp {^\ *(input|output|inout)\ *\[\ *([0-9]+)\ *\*\ *([A-Z_]+)\ *-\ *1\ *:\ *0\ *\]\ *([a-z0-9_]+)} $file_line match_string io_dir io_width_fix io_width_var io_name]} {
                ui::addPin -dir $io_dir  -name $io_name -bus -msb [expr [ui::getValue -name "$io_width_var"] * $io_width_fix - 1] -text "$io_name"
                foreach show_name $show_switch_list { lappend $show_name $io_name }
                lappend "pin_show_b_$io_width_var" $io_name
                lappend "fix_pin_show_b_$io_width_var" $io_width_fix
            }

            if {[regexp {^\ *<show param='([a-zA-Z0-9_]+)'>} $file_line match_string show_switch]} {
                lappend show_switch_list "pin_show_$show_switch"
            } elseif {[regexp {^\ *</show>} $file_line]} {
                set len [llength $show_switch_list]
                set show_switch_list [lreplace $show_switch_list [expr $len-1] $len]
            }
        }
        incr line_cnt
    }
    close $pins_in_file
}

#create configuration

proc CreateCfgLayout {} {

    # mLayout
    ui::addVBox -name mLayout
    ui::addStackedWidget -name mTab -parent mLayout

    # First Tab
    ui::addStackedPage -name pTab1 -t "Step 1: Basic Options" -parent mTab
    ui::addVBox -name TOPVBox1 -p pTab1

    ui::addGroupBox -name page1_seting1 -t "Type Options" -p TOPVBox1
    ui::addVBox -name M_VBox -p page1_seting1

    ui::addHBox -name Mem_VBox1 -p M_VBox
    ui::addLabel -text "Please select the memory interface type from the Memory Type selection." -parent Mem_VBox1

    ui::addGrid -name Mem_VBox -p M_VBox
    set curRow 0
    ui::addLabel -text "Memory Type:" -parent Mem_VBox -column 0 -row $curRow
    ui::addComboBox -name "MEM_TYPE" -text "DDR3" -parent Mem_VBox -column 1 -row $curRow
    ui::addLabel -text " " -parent Mem_VBox -column 2 -row $curRow
    ui::addLabel -text " " -parent Mem_VBox -column 3 -row $curRow
    ui::addLabel -text " " -parent Mem_VBox -column 4 -row $curRow
    ui::addLabel -text " " -parent Mem_VBox -column 5 -row $curRow

    ui::addGroupBox -name page1_seting3 -t "Mode Options" -p TOPVBox1
    ui::addVBox -name O_VBox -p page1_seting3

    ui::addHBox -name Oper_VBox1 -p O_VBox
    ui::addLabel -text "Please select the operating mode for memory Interface." -parent Oper_VBox1

    ui::addGrid -name Oper_VBox -p O_VBox
    set curRow 0
    ui::addLabel -text "Operating Mode:" -parent Oper_VBox -column 0 -row $curRow
    ui::addComboBox -name "OPERATING_MODE" -text "Controller + PHY" -parent Oper_VBox -column 1 -row $curRow
    ui::addLabel -text " " -parent Oper_VBox -column 2 -row $curRow
    ui::addLabel -text " " -parent Oper_VBox -column 3 -row $curRow
    ui::addLabel -text " " -parent Oper_VBox -column 4 -row $curRow
    ui::addLabel -text " " -parent Oper_VBox -column 5 -row $curRow

    ui::addGroupBox -name page1_seting4 -t "Width Options" -p TOPVBox1
    ui::addVBox -name T_VBox -p page1_seting4

    ui::addHBox -name TDQ_VBox1 -p T_VBox
    ui::addLabel -text "Please select the data width which memory interface can access at a time." -parent TDQ_VBox1

    ui::addGrid -name TDQ_VBox -p T_VBox
    set curRow 0
    ui::addLabel -text "Total Data Width:" -parent TDQ_VBox -column 0 -row $curRow
    ui::addComboBox -name "MEM_DQ_WIDTH" -parent TDQ_VBox -column 1 -row $curRow
    ui::addLabel -text " " -parent TDQ_VBox -column 2 -row $curRow
    ui::addLabel -text " " -parent TDQ_VBox -column 3 -row $curRow
    ui::addLabel -text " " -parent TDQ_VBox -column 4 -row $curRow
    ui::addLabel -text " " -parent TDQ_VBox -column 5 -row $curRow

    ui::addGroupBox -name page1_seting5 -t "Clock settings" -p TOPVBox1
    ui::addVBox -name C_VBox -p page1_seting5

    ui::addGrid -name CLO_VBox -p C_VBox
    set curRow 0
    ui::addLabel -text "Input Clock Frequency:" -parent CLO_VBox -column 0 -row $curRow
    ui::addDoubleSpinBox -name "CLKIN_FREQ" -parent  CLO_VBox -column 1 -row $curRow
    ui::addLabel  -text "MHz(range:5-625MHz)" -align left -p CLO_VBox -column 2 -row $curRow
    ui::addLabel -text " " -parent CLO_VBox -column 3 -row $curRow
    ui::addLabel -text " " -parent CLO_VBox -column 4 -row $curRow
    ui::addLabel -text " " -parent CLO_VBox -column 5 -row $curRow

    incr curRow
    ui::addLabel -text "Desired Data Rate:" -parent CLO_VBox -column 0 -row $curRow
    ui::addDoubleSpinBox -name "DESIRED_DDR3_RATE" -parent CLO_VBox -column 1 -row $curRow
    ui::addLabel  -name data_rate_txt  -text "Mbps(range:600-800Mbps)" -align left -p CLO_VBox -column 2 -row $curRow

    incr curRow
    ui::addLabel -text "Actual Data Rate:" -parent CLO_VBox -column 0 -row $curRow
    ui::addLabel -name "ACTUAL_RATE_txt" -text "800.00" -parent CLO_VBox -column 1 -row $curRow
    ui::addLabel -text "Mbps" -align left -p CLO_VBox -column 2 -row $curRow

    ui::addGroupBox -name page1_ddr3_seting6 -t "Write and Read Latency" -p TOPVBox1
    ui::addVBox -name DDR3_L_VBox -p page1_ddr3_seting6
    ui::addGrid -name Lat_DDR3 -p DDR3_L_VBox

    set curRow 0
    ui::addLabel -text "CAS Write Latency(CWL):" -parent Lat_DDR3 -column 0 -row $curRow
    ui::addComboBox -name "GUI_DDR3_CWL_800" -text "5" -parent Lat_DDR3 -column 1 -row $curRow
    ui::addLabel -name "DDR3_CWL_TXT" -text "tCK(range: 5)" -parent Lat_DDR3 -column 2 -row $curRow
    ui::addLabel -text " " -parent Lat_DDR3 -column 3 -row $curRow
    ui::addLabel -text " " -parent Lat_DDR3 -column 4 -row $curRow
    ui::addLabel -text " " -parent Lat_DDR3 -column 5 -row $curRow

    incr curRow
    ui::addLabel -text "CAS Latency(CL):" -parent Lat_DDR3 -column 0 -row $curRow
    ui::addComboBox -name "GUI_DDR3_CL_800" -text "5" "6" -parent Lat_DDR3 -column 1 -row $curRow
    ui::addLabel -name "DDR3_CL_TXT" -text "tCK(range: 5-6)" -parent Lat_DDR3 -column 2 -row $curRow

    incr curRow
    ui::addLabel -text "Additive Latency(AL):" -parent Lat_DDR3 -column 0 -row $curRow
    ui::addComboBox -name "GUI_DDR3_AL" -text "0" "CL-2" -parent Lat_DDR3 -column 1 -row $curRow
    ui::addLabel -text "tCK" -parent Lat_DDR3 -column 2 -row $curRow    

    ui::addGroupBox -name Group_error_correct -t "Debug Signals" -p TOPVBox1
    ui::addVBox -name Port_Cor -p Group_error_correct
    ui::addGrid -name DEBUG_en -p Port_Cor

    set curRow 0
    ui::addCheckBox -name "Debug_Signals_En" -text "Enable Debug Signals"  -p Port_Cor -column 0 -row $curRow
    ui::addSpacer -p TOPVBox1

    # Second Tab
    ui::addStackedPage -name pTab2 -t "Step 2: Memory Options" -parent mTab
    ui::addVBox -name TOPVBox2 -p pTab2

    ui::addGroupBox -name page2_seting1 -t "Memory Part" -p TOPVBox2
    ui::addVBox -name MP_VBox -p page2_seting1

    ui::addHBox -name MP_VBox1 -p MP_VBox
    ui::addLabel -text "Please select the memory part.Find an equivalent part or create a part using the 'Create Custom Part' button if the part you want is not listed here." -parent MP_VBox1
    ui::addGrid -name MP_VBox2 -p MP_VBox
    set curRow 0
    ui::addCheckBox -name "CUSTOMIZE_MEM" -text "Create Custom Part" -parent MP_VBox2 -column 0 -row $curRow
    ui::addComboBox -name "DDR3_DFT_MEM_PART" -text "MT41J128M8xx-15E" "MT41J128M16xx-15E" "MT41J64M16xx-15E" "MT41J256M8xx-15E" "MT41K256M16xx-15E" -parent MP_VBox2 -column 1 -row $curRow
    ui::addLabel -text " " -parent MP_VBox2 -column 2 -row $curRow
    ui::addLabel -text " " -parent MP_VBox2 -column 3 -row $curRow
    ui::addLabel -text " " -parent MP_VBox2 -column 4 -row $curRow
    ui::addLabel -text " " -parent MP_VBox2 -column 5 -row $curRow


    ui::addGroupBox -name page2_seting2 -t "Custom Memory Part" -p TOPVBox2
    ui::addVBox -name CM_VBox -p page2_seting2

    ui::addHBox -name CM_VBox1 -p CM_VBox
    ui::addLabel -text "This option creates a new memory part. Note that the new part will be a modification of the 'Base Part' you select below." -parent CM_VBox1
    ui::addHBox -name CM_VBox2 -p CM_VBox
    ui::addLabel -text "The timing parameters and the density can be changed. Custom memory parts are not simulated and not hardware validated." -parent CM_VBox2

    ui::addGrid -name CM_VBox3 -p CM_VBox
    set curRow 0
    ui::addLabel -text "Select Base Part:" -parent CM_VBox3 -column 0 -row $curRow
    ui::addComboBox -name "DDR3_BASE_MEM_PART" -text "MT41J128M8xx-15E" "MT41J128M16xx-15E" "MT41J64M16xx-15E" "MT41J256M8xx-15E" "MT41K256M16xx-15E" -parent CM_VBox3 -column 1 -row $curRow
    ui::addLabel -text " " -parent CM_VBox3 -column 2 -row $curRow
    ui::addLabel -text " " -parent CM_VBox3 -column 3 -row $curRow
    ui::addLabel -text " " -parent CM_VBox3 -column 4 -row $curRow
    ui::addLabel -text " " -parent CM_VBox3 -column 5 -row $curRow

    #ddr3
    ui::addGroupBox -name page2_ddr3_seting -t "Timing Parameters" -p CM_VBox
    ui::addVBox -name DDR3_VBox -p page2_ddr3_seting
    ui::addGrid -name DDR3_PAR -p DDR3_VBox
    set curRow 0
    ui::addLabel -text "Parameter" -parent DDR3_PAR -column 0 -row $curRow
    ui::addLabel -text "Value" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "Range" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "Units" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Descriptions" -parent DDR3_PAR -column 4 -row $curRow
    ui::addLabel -text " " -parent DDR3_PAR -column 5 -row $curRow

    incr curRow
    ui::addLabel -text "trfc" -parent DDR3_PAR -column 0 -row $curRow
    ui::addDoubleSpinBox -name "GUI_DDR3_TRFC" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "90-350" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "ns" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Refresh to Active or Refresh to Refresh" -parent DDR3_PAR -column 4 -row $curRow

    incr curRow
    ui::addLabel -text "tras" -parent DDR3_PAR -column 0 -row $curRow
    ui::addDoubleSpinBox -name "GUI_DDR3_TRAS" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "35-37.5" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "ns" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Active to Precharge command" -parent DDR3_PAR -column 4 -row $curRow

    incr curRow
    ui::addLabel -text "trp" -parent DDR3_PAR -column 0 -row $curRow
    ui::addDoubleSpinBox -name "GUI_DDR3_TRP" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "10-15" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "ns" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Precharge command period" -parent DDR3_PAR -column 4 -row $curRow

    incr curRow
    ui::addLabel -text "trcd" -parent DDR3_PAR -column 0 -row $curRow
    ui::addDoubleSpinBox -name "GUI_DDR3_TRCD" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "10-15" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "ns" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Active to Read or Write delay" -parent DDR3_PAR -column 4 -row $curRow

    incr curRow
    ui::addLabel -text "twr" -parent DDR3_PAR -column 0 -row $curRow
    ui::addDoubleSpinBox -name "GUI_DDR3_TWR" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "15-15" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "ns" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Write recovery time" -parent DDR3_PAR -column 4 -row $curRow

    incr curRow
    ui::addLabel -text "trefi" -parent DDR3_PAR -column 0 -row $curRow
    ui::addDoubleSpinBox -name "GUI_DDR3_TREFI" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "1-7.8" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "us" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Average periodic refresh interval" -parent DDR3_PAR -column 4 -row $curRow

    incr curRow
    ui::addLabel -text "trtp" -parent DDR3_PAR -column 0 -row $curRow
    ui::addDoubleSpinBox -name "GUI_DDR3_TRTP" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "7.5-7.5" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "ns" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Internal Read to Precharge command delay" -parent DDR3_PAR -column 4 -row $curRow

    incr curRow
    ui::addLabel -text "twtr" -parent DDR3_PAR -column 0 -row $curRow
    ui::addDoubleSpinBox -name "GUI_DDR3_TWTR" -parent DDR3_PAR -column 1 -row $curRow
    ui::addLabel -text "7.5-7.5" -parent DDR3_PAR -column 2 -row $curRow
    ui::addLabel -text "ns" -parent DDR3_PAR -column 3 -row $curRow
    ui::addLabel -text "Read following a Write to the same device" -parent DDR3_PAR -column 4 -row $curRow

    #ddr3
    ui::addGroupBox -name page2_ddr3ad_seting -p CM_VBox
    ui::addVBox -name DDR3AD_VBox -p page2_ddr3ad_seting
    ui::addGrid -name DDR3AD_VBox4 -p DDR3AD_VBox

    set curRow 0
    ui::addLabel -text "Row Address:" -parent DDR3AD_VBox4 -column 0 -row $curRow
    ui::addComboBox -name "DDR3_MEM_ROW_WIDTH" -text "13" "14" "15" -parent DDR3AD_VBox4 -column 1 -row $curRow
    ui::addLabel -text " " -parent DDR3AD_VBox4 -column 2 -row $curRow
    ui::addLabel -text " " -parent DDR3AD_VBox4 -column 3 -row $curRow
    ui::addLabel -text " " -parent DDR3AD_VBox4 -column 4 -row $curRow
    ui::addLabel -text " " -parent DDR3AD_VBox4 -column 5 -row $curRow

    incr curRow
    ui::addLabel -text "Column Address:" -parent DDR3AD_VBox4 -column 0 -row $curRow
    ui::addComboBox -name "DDR3_MEM_COLUMN_WIDTH" -text "8" "9" "10" "11" -parent DDR3AD_VBox4 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Bank Address:" -parent DDR3AD_VBox4 -column 0 -row $curRow
    ui::addComboBox -name "DDR3_MEM_BANK_WIDTH" -text "3" -parent DDR3AD_VBox4 -column 1 -row $curRow

    ui::addGroupBox -name page2_seting4 -t "Drive Options" -p TOPVBox2
    ui::addVBox -name DO_VBox -p page2_seting4

    #ddr3
    ui::addGroupBox -name DDR3_OUT -t "" -p DO_VBox
    ui::addVBox -name DDR3_OUT1 -p DDR3_OUT

    ui::addHBox -name DDR3_OUT2 -p DDR3_OUT1
    ui::addLabel -text "To calibrate the output driver impedance, an external precision resistor (RZQ) is connected between the ZQ ball and VSSQ." -parent DDR3_OUT2
    ui::addHBox -name DDR3_OUT3 -p DDR3_OUT1
    ui::addLabel -text "The value of the resistor must be 240ohm +/-1 percent." -parent DDR3_OUT3

    ui::addGrid -name DDR3_OUT4 -p DDR3_OUT1
    set curRow 0
    ui::addLabel -text "Output Driver Impedance Control:" -parent DDR3_OUT4 -column 0 -row $curRow
    ui::addComboBox -name "DDR3_OUTPUT_DRIVER" -text "RZQ/6" "RZQ/7" -parent DDR3_OUT4 -column 1 -row $curRow
    ui::addLabel -text " " -parent DDR3_OUT4 -column 2 -row $curRow
    ui::addLabel -text " " -parent DDR3_OUT4 -column 3 -row $curRow
    ui::addLabel -text " " -parent DDR3_OUT4 -column 4 -row $curRow
    ui::addLabel -text " " -parent DDR3_OUT4 -column 5 -row $curRow

    ui::addGroupBox -name DDR3_ODT -t "" -p DO_VBox
    ui::addVBox -name DDR3_ODT1 -p DDR3_ODT

    ui::addHBox -name DDR3_ODT2 -p DDR3_ODT1
    ui::addLabel -text "The ODT feature is designed to improve signal integrity of the memory channel by enabling the DDR3 SDRAM controller to" -parent DDR3_ODT2
    ui::addHBox -name DDR3_ODT3 -p DDR3_ODT1
    ui::addLabel -text "independently turn on/off ODT." -parent DDR3_ODT3

    ui::addGrid -name DDR3_ODT4 -p DDR3_ODT1
    set curRow 0
    ui::addLabel -text "RTT(nominal)-ODT:" -parent DDR3_ODT4 -column 0 -row $curRow
    ui::addComboBox -name "DDR3_ODT_VALUE" -text "RZQ/4" "RZQ/2" "RZQ/6" -parent DDR3_ODT4 -column 1 -row $curRow
    ui::addLabel -text " " -parent DDR3_ODT4 -column 2 -row $curRow
    ui::addLabel -text " " -parent DDR3_ODT4 -column 3 -row $curRow
    ui::addLabel -text " " -parent DDR3_ODT4 -column 4 -row $curRow
    ui::addLabel -text " " -parent DDR3_ODT4 -column 5 -row $curRow

    ui::addSpacer -p TOPVBox2

    # The third Tab
    ui::addStackedPage -name pTab3 -t "Step 3: Pin/Bank Options" -parent mTab
    ui::addVBox -name TOPVBox3 -p pTab3

    ui::addGroupBox -name page3_seting0 -t "Memory Pin Constraint File Select" -p TOPVBox3
    ui::addVBox -name PO_VBox0 -p page3_seting0
    ui::addLabel -text "Please select a fdc file which contains default memory pins constraint." -p PO_VBox0 -column 0 -row 0
    ui::addCheckBox -name "USER_PINS_CON_EN" -text "Enable fdc file select"  -p PO_VBox0 -column 0 -row 1
    ui::addHBox -name PO_HBox0 -p PO_VBox0
    ui::addLineEdit -name "USER_FDC_PATH" -text "Please select a fdc file" -cs 2 -p PO_HBox0 -column 0 -row 0
    ui::addButton -name "USER_FDC_BROWSE" -text "Browse..." -selfile -to "USER_FDC_PATH" -p PO_HBox0 -column 3 -row 0 

    ui::addGroupBox -name page3_seting1 -t "Control/Address Pin Options" -p TOPVBox3
    ui::addVBox -name PO_Box -p page3_seting1

    ui::addGroupBox -name page3_seting2  -p PO_Box
    ui::addVBox -name PO_VBox -p page3_seting2
    ui::addHBox -name PO_Box1 -p PO_VBox
    ui::addLabel -text "Please select the banks for the Control/Address in the architectural view below." -parent PO_Box1 -column 0 -row $curRow
    ui::addGrid -name PO_Box2 -p PO_VBox
    set curRow 0
    ui::addLabel -text "Control/Address Bank:" -parent PO_Box2 -column 0 -row $curRow
    ui::addComboBox -name "BANK_CA" -text "B1" "B3" -parent PO_Box2 -column 1 -row $curRow
    ui::addLabel -text " " -parent PO_Box2 -column 2 -row $curRow
    ui::addLabel -text " " -parent PO_Box2 -column 3 -row $curRow
    ui::addLabel -text " " -parent PO_Box2 -column 4 -row $curRow

    ui::addGroupBox -name page3_seting6  -p PO_Box
    ui::addVBox -name PO_VBox6 -p page3_seting6
    ui::addVBox -name PO_Box3_6 -p PO_VBox6
    set curRow 0
    ui::addLabel -text "Please select the pins for the Control/Address in the architectural view below." -parent PO_Box3_6 -column 0 -row $curRow
    incr curRow
    ui::addCheckBox -name "CS_n_En" -text "Enable CS_n(if cs_n is disabled,it should be considered NF maintained LOW through an external resister to GND)"  -p PO_Box3_6 -column 0 -row $curRow

    ui::addGroupBox -name page3_seting3  -p PO_Box
    ui::addVBox -name PO_VBox1 -p page3_seting3
    ui::addVBox -name PO_Box3 -p PO_VBox1
    set curRow 0
    ui::addLabel -text "Please select the groups for the Control/Address in the architectural view below." -parent PO_Box3 -column 0 -row $curRow
    incr curRow
    ui::addCheckBox -name "CUSTOMIZE_CA" -text "Custom Control/Address Group" -parent PO_Box3 -column 0 -row $curRow
    incr curRow
    ui::addLabel -name "NOTE_CA" -text "    Note: Confirm to assign Control/Address signals to different pins. Incorrect \"Pin Number\" will be marked in red." -parent PO_Box3 -column 0 -row $curRow

    ui::addGroupBox -name ca_group_seting1  -p PO_Box
    ui::addVBox -name PO_VBox4 -p ca_group_seting1
    ui::addGrid -name PO_VBox5 -p PO_VBox4
    set curRow 0
    ui::addLabel -text "Signal Name" -parent PO_VBox5 -column 0 -row $curRow
    ui::addLabel -text "Group Number" -parent PO_VBox5 -column 1 -row $curRow
    ui::addLabel -text "Pin Number" -parent PO_VBox5 -column 2 -row $curRow
    ui::addLabel -text " " -parent PO_VBox5 -column 3 -row $curRow
    ui::addLabel -text " " -parent PO_VBox5 -column 4 -row $curRow
    incr curRow
    ui::addLabel -name reset_txt0 -text "RESET" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "PAD_RESET" -text "W4" -parent PO_VBox5 -column 2 -row $curRow

    incr curRow
    ui::addLabel -text "CKE" -parent PO_VBox5 -column 0 -row $curRow    
    ui::addComboBox -name "GROUP_CKE" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_CKE" -text "AE1" -parent PO_VBox5 -column 2 -row $curRow

    incr curRow
    ui::addLabel -text "CK" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_CK" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_CK" -text "V4" -parent PO_VBox5 -column 2 -row $curRow
   
    incr curRow
    ui::addLabel -text "CK_N" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_CKN" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_CKN" -text "V3" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name CS_txt -text "CS" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_CS" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_CS" -text "V1" -parent PO_VBox5 -column 2 -row $curRow
   
    incr curRow
    ui::addLabel -name RAS_txt -text "RAS" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_RAS" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_RAS" -text "U3" -parent PO_VBox5 -column 2 -row $curRow
   
    incr curRow
    ui::addLabel -name CAS_txt -text "CAS" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_CAS" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_CAS" -text "T3" -parent PO_VBox5 -column 2 -row $curRow
   
    incr curRow
    ui::addLabel -name WE_txt -text "WE" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_WE" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_WE" -text "R5" -parent PO_VBox5 -column 2 -row $curRow

    incr curRow
    ui::addLabel -name ODT_txt -text "ODT" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_ODT" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_ODT" -text "V2" -parent PO_VBox5 -column 2 -row $curRow
  
    incr curRow
    ui::addLabel -text "BA0" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_BA0" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_BA0" -text "U1" -parent PO_VBox5 -column 2 -row $curRow
   
    incr curRow
    ui::addLabel -text "BA1" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_BA1" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_BA1" -text "P3" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name BA2_txt -text "BA2" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_BA2" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_BA2" -text "R4" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name blank0 -text " " -parent PO_VBox5 -column 0 -row $curRow
    
    incr curRow
    ui::addLabel -text "A0" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A0" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A0" -text "U4" -parent PO_VBox5 -column 2 -row $curRow
   
    incr curRow
    ui::addLabel -text "A1" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A1" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A1" -text "P4" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -text "A2" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A2" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A2" -text "U5" -parent PO_VBox5 -column 2 -row $curRow
   
    incr curRow
    ui::addLabel -text "A3" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A3" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A3" -text "T2" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -text "A4" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A4" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A4" -text "N3" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -text "A5" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A5" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A5" -text "T1" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -text "A6" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A6" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A6" -text "N4" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -text "A7" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A7" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A7" -text "R1" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -text "A8" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A8" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A8" -text "N5" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name blank1 -text " " -parent PO_VBox5 -column 0 -row $curRow
    
    incr curRow
    ui::addLabel -text "A9" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A9" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A9" -text "P2" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -text "A10" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A10" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A10" -text "T4" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name A11_txt -text "A11" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A11" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A11" -text "P6" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name A12_txt -text "A12" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A12" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A12" -text "R3" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name A13_txt -text "A13" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A13" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A13" -text "N1" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name A14_txt -text "A14" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A14" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A14" -text "P7" -parent PO_VBox5 -column 2 -row $curRow
   
    incr curRow
    ui::addLabel -name A15_txt -text "A15" -parent PO_VBox5 -column 0 -row $curRow
    ui::addComboBox -name "GROUP_A15" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox5 -column 1 -row $curRow
    ui::addComboBox -name "PAD_A15" -text "M7" -parent PO_VBox5 -column 2 -row $curRow
    
    incr curRow
    ui::addLabel -name blank2 -text " " -parent PO_VBox5 -column 0 -row $curRow

    ui::addGroupBox -name page3_seting4 -t "Data Pin Options" -p TOPVBox3
    ui::addVBox -name PO_Box6 -p page3_seting4
    ui::addLabel -text "Please select the banks and groups for the data in the architectural view below." -parent PO_Box6 -column 0 -row $curRow

    ui::addGroupBox -name page3_seting5  -p PO_Box6
    ui::addVBox -name PO_VBox7 -p page3_seting5
    ui::addGrid -name PO_VBox8 -p PO_VBox7
    set curRow 0
    ui::addLabel -text "Signal Name" -parent PO_VBox8 -column 0 -row $curRow
    ui::addLabel -text "Bank Number" -parent PO_VBox8 -column 1 -row $curRow
    ui::addLabel -text "Group Number" -parent PO_VBox8 -column 2 -row $curRow
    ui::addLabel -text " " -parent PO_VBox8 -column 3 -row $curRow
    ui::addLabel -text " " -parent PO_VBox8 -column 4 -row $curRow

    incr curRow
    ui::addLabel -name dq_txt0 -text "DQ\[0-7\]" -parent PO_VBox8 -column 0 -row $curRow
    ui::addComboBox -name "BANK_DQG_0" -text "B1" "B3" -parent PO_VBox8 -column 1 -row $curRow
    ui::addComboBox -name "GROUP_DQG_0" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox8 -column 2 -row $curRow

    incr curRow
    ui::addLabel -name dq_txt1 -text "DQ\[8-15\]" -parent PO_VBox8 -column 0 -row $curRow
    ui::addComboBox -name "BANK_DQG_1" -text "B1" "B3" -parent PO_VBox8 -column 1 -row $curRow
    ui::addComboBox -name "GROUP_DQG_1" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox8 -column 2 -row $curRow

    incr curRow
    ui::addLabel -name dq_txt2 -text "DQ\[16-23\]" -parent PO_VBox8 -column 0 -row $curRow
    ui::addComboBox -name "BANK_DQG_2" -text "B1" "B3" -parent PO_VBox8 -column 1 -row $curRow
    ui::addComboBox -name "GROUP_DQG_2" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox8 -column 2 -row $curRow

    incr curRow
    ui::addLabel -name dq_txt3 -text "DQ\[24-31\]" -parent PO_VBox8 -column 0 -row $curRow
    ui::addComboBox -name "BANK_DQG_3" -text "B1" "B3" -parent PO_VBox8 -column 1 -row $curRow
    ui::addComboBox -name "GROUP_DQG_3" -text "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8" -parent PO_VBox8 -column 2 -row $curRow 

    ui::addSpacer -p TOPVBox3

    # The fourth Tab
    ui::addStackedPage -name pTab4 -t "Step 4: Summary" -parent mTab
    ui::addVBox -name TOPVBox4 -p pTab4

    ui::addGroupBox -name page4_seting1 -t "Basic Options" -p TOPVBox4
    ui::addVBox -name SU_Box -p page4_seting1

    ui::addGrid -name SU_Box1 -p SU_Box
    set curRow 0
    ui::addLabel -text "Memory Type" -parent SU_Box1 -column 0 -row $curRow
    ui::addLabel -name "Memory_Type_txt" -text ": DDR3" -parent SU_Box1 -column 1 -row $curRow
    ui::addLabel -text " " -parent SU_Box1 -column 2 -row $curRow
    ui::addLabel -text " " -parent SU_Box1 -column 3 -row $curRow
    ui::addLabel -text " " -parent SU_Box1 -column 4 -row $curRow
    ui::addLabel -text " " -parent SU_Box1 -column 5 -row $curRow

    incr curRow
    ui::addLabel -text "Operating Mode" -parent SU_Box1 -column 0 -row $curRow
    ui::addLabel -name "Operating_Mode_txt" -text ": Controller + PHY" -parent SU_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Total Data Width" -parent SU_Box1 -column 0 -row $curRow
    ui::addLabel -name "Total_Data_Width_txt" -text ": 16" -parent SU_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Density" -parent SU_Box1 -column 0 -row $curRow
    ui::addLabel -name "Density_txt" -text ": 2Gb" -parent SU_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Volt" -parent SU_Box1 -column 0 -row $curRow
    ui::addLabel -name "Volt_txt" -text ": 1.5V" -parent SU_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Input Clock Frequency" -parent SU_Box1 -column 0 -row $curRow
    ui::addLabel -name "Input_Clock_txt" -text ": 50.00MHz" -parent SU_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Data Rate" -parent SU_Box1 -column 0 -row $curRow
    ui::addLabel -name "Data_Rate_txt" -text ": 800.00Mbps" -parent SU_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Debug Signals" -parent SU_Box1 -column 0 -row $curRow
    ui::addLabel -name "Debug_Signals_txt" -text ": Enabled" -parent SU_Box1 -column 1 -row $curRow

    ui::addGroupBox -name page4_seting2 -t "Memory Options" -p TOPVBox4
    ui::addVBox -name MO_Box -p page4_seting2

    ui::addGrid -name MO_Box1 -p MO_Box
    set curRow 0
    ui::addLabel -text "Memory Part" -parent MO_Box1 -column 0 -row $curRow
    ui::addLabel -name "Memory_Part_txt" -text ": MT41K256M16TW-107IT:P" -parent MO_Box1 -column 1 -row $curRow
    ui::addLabel -text " " -parent MO_Box1 -column 2 -row $curRow
    ui::addLabel -text " " -parent MO_Box1 -column 3 -row $curRow
    ui::addLabel -text " " -parent MO_Box1 -column 4 -row $curRow
    ui::addLabel -text " " -parent MO_Box1 -column 5 -row $curRow

    incr curRow
    ui::addLabel -text "Row Address" -parent MO_Box1 -column 0 -row $curRow
    ui::addLabel -name "Row_Address_txt" -text ": 15" -parent MO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Column Address" -parent MO_Box1 -column 0 -row $curRow
    ui::addLabel -name "Column_Address_txt" -text ": 10" -parent MO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -text "Bank Address" -parent MO_Box1 -column 0 -row $curRow
    ui::addLabel -name "Bank_Address_txt" -text ": 3" -parent MO_Box1 -column 1 -row $curRow

    #ddr3
    incr curRow
    ui::addLabel -name "DDR3_Output_Driver" -text "Output Driver Impedance Control" -parent MO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DDR3_Output_Driver_txt" -text ": RZQ/6" -parent MO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name "DDR3_RTT_ODT" -text "RTT(nominal)-ODT" -parent MO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DDR3_RTT_ODT_txt" -text ": RZQ/4" -parent MO_Box1 -column 1 -row $curRow


    ui::addGroupBox -name page4_seting3 -t "Pin/Bank Options" -p TOPVBox4
    ui::addVBox -name INO_Box -p page4_seting3

    ui::addGrid -name INO_Box1 -p INO_Box

    set curRow 0
    ui::addLabel -text "Control/Address Bank" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "CA_txt" -text ": B1" -parent INO_Box1 -column 1 -row $curRow
    ui::addLabel -text " " -parent INO_Box1 -column 2 -row $curRow
    ui::addLabel -text " " -parent INO_Box1 -column 3 -row $curRow
    ui::addLabel -text " " -parent INO_Box1 -column 4 -row $curRow
    ui::addLabel -text " " -parent INO_Box1 -column 5 -row $curRow

    incr curRow
    ui::addLabel -text "CS_n" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "CS_n_txt" -text ": Enabled" -parent INO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name dq0_txt -text "DQ\[0-7\] Bank" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DQ0_txt" -text ": B1" -parent INO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name dq1_txt -text "DQ\[8-15\] Bank" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DQ1_txt" -text ": B1" -parent INO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name dq2_txt -text "DQ\[16-23\] Bank" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DQ2_txt" -text ": B1" -parent INO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name dq3_txt -text "DQ\[24-31\] Bank" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DQ3_txt" -text ": B1" -parent INO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name dq0_group_txt -text "DQ\[0-7\] Group" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DQ0_group_txt" -text ": G0" -parent INO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name dq1_group_txt -text "DQ\[8-15\] Group" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DQ1_group_txt" -text ": G0" -parent INO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name dq2_group_txt -text "DQ\[16-23\] Group" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DQ2_group_txt" -text ": G0" -parent INO_Box1 -column 1 -row $curRow

    incr curRow
    ui::addLabel -name dq3_group_txt -text "DQ\[24-31\] Group" -parent INO_Box1 -column 0 -row $curRow
    ui::addLabel -name "DQ3_group_txt" -text ": G0" -parent INO_Box1 -column 1 -row $curRow


    ui::addSpinBox  -name "DDR3_INIT_WR"            -parent TOPVBox4
    ui::addSpinBox  -name "DDR3_CL_VALUE"           -parent TOPVBox4
    ui::addSpinBox  -name "DDR3_WR"                 -parent TOPVBox4
    ui::addSpinBox  -name "PHY_TMRD"                -parent TOPVBox4
    ui::addSpinBox  -name "PHY_TMOD"                -parent TOPVBox4
    ui::addSpinBox  -name "PHY_TXPR"                -parent TOPVBox4
    ui::addSpinBox  -name "PHY_TRP"                 -parent TOPVBox4
    ui::addSpinBox  -name "PHY_TRFC"                -parent TOPVBox4
    ui::addSpinBox  -name "PHY_TRCD"                -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_TRFC"               -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_TREFI"              -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_FAW"              -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_RAS"              -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_XP"               -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_RC"               -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_RRD"              -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_RP"               -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_RCD"              -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_RTP"              -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_WR"               -parent TOPVBox4
    ui::addSpinBox  -name "DDRC_T_WTR"              -parent TOPVBox4
    ui::addComboBox  -name "DDR_MEM_PART"           -parent TOPVBox4
    ui::addDoubleSpinBox -name "DESIRED_RATE"       -parent TOPVBox4
    ui::addDoubleSpinBox -name "ACTUAL_RATE"        -parent TOPVBox4
    ui::addSpinBox  -name "STATIC_RATIOI"           -parent TOPVBox4
    ui::addSpinBox  -name "STATIC_RATIOF"           -parent TOPVBox4
    ui::addSpinBox  -name "STATIC_RATIO0"           -parent TOPVBox4
    ui::addSpinBox -name "DDR3_CWL"                 -parent TOPVBox4
    ui::addSpinBox -name "DDR3_CL"                  -parent TOPVBox4
    ui::addSpinBox -name "DDR3_AL"                  -parent TOPVBox4

    ui::addSpinBox  -name "tREFI"                   -parent TOPVBox4
    ui::addDoubleSpinBox  -name "tRFC_MIN"          -parent TOPVBox4
    ui::addSpinBox  -name "DFI_CLK_PERIOD"          -parent TOPVBox4

    ui::addComboBox -name "DEVICE_100H" -parent TOPVBox4

    ui::addComboBox -name "MEM_BANK_WIDTH" -parent TOPVBox4
    ui::addComboBox -name "MEM_ROW_WIDTH" -parent TOPVBox4
    ui::addComboBox -name "MEM_ADDR_WIDTH" -parent TOPVBox4
    ui::addComboBox -name "MEM_COLUMN_WIDTH" -parent TOPVBox4
    ui::addComboBox -name "MEM_DM_WIDTH" -parent TOPVBox4
    ui::addComboBox -name "MEM_DQS_WIDTH" -parent TOPVBox4
    ui::addComboBox -name "CTRL_ADDR_WIDTH" -parent TOPVBox4

    ui::addComboBox -name "A0_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A1_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A2_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A3_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A4_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A5_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A6_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A7_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A8_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A9_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A10_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A11_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A12_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A13_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A14_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "A15_GROUP_NUM" -parent TOPVBox4

    ui::addComboBox -name "CKE_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "CK_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "CS_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "RAS_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "CAS_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "WE_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "ODT_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "BA0_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "BA1_GROUP_NUM" -parent TOPVBox4
    ui::addComboBox -name "BA2_GROUP_NUM" -parent TOPVBox4

    ui::addSpinBox -name "CA_GROUP_A0" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A1" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A2" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A3" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A4" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A5" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A6" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A7" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A8" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A9" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A10" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A11" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A12" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A13" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A14" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_A15" -parent TOPVBox4

    ui::addSpinBox -name "CA_GROUP_CKE" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_CK" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_CS" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_RAS" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_CAS" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_WE" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_ODT" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_BA0" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_BA1" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP_BA2" -parent TOPVBox4

    ui::addComboBox -name "CA_GROUP0" -parent TOPVBox4
    ui::addComboBox -name "CA_GROUP1" -parent TOPVBox4
    ui::addComboBox -name "CA_GROUP2" -parent TOPVBox4
    ui::addComboBox -name "CA_GROUP3" -parent TOPVBox4
    ui::addComboBox -name "CA_GROUP4" -parent TOPVBox4

    ui::addSpinBox -name "CA_GROUP0_REG" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP1_REG" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP2_REG" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP3_REG" -parent TOPVBox4
    ui::addSpinBox -name "CA_GROUP4_REG" -parent TOPVBox4

    ui::addSpinBox -name "GROUP_DQG_0_NUM" -parent TOPVBox4
    ui::addSpinBox -name "GROUP_DQG_1_NUM" -parent TOPVBox4
    ui::addSpinBox -name "GROUP_DQG_2_NUM" -parent TOPVBox4
    ui::addSpinBox -name "GROUP_DQG_3_NUM" -parent TOPVBox4

    ui::addComboBox -name "A0_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A1_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A2_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A3_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A4_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A5_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A6_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A7_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A8_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A9_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A10_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A11_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A12_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A13_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A14_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "A15_REG_NUM" -parent TOPVBox4

    ui::addComboBox -name "CKE_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "CK_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "CS_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "RAS_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "CAS_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "WE_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "ODT_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "BA0_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "BA1_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "BA2_REG_NUM" -parent TOPVBox4

    ui::addComboBox -name "DQG_0_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "DQG_1_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "DQG_2_REG_NUM" -parent TOPVBox4
    ui::addComboBox -name "DQG_3_REG_NUM" -parent TOPVBox4

    ui::addTextEdit  -name "DQS_TEST"      -parent TOPVBox4
    ui::addTextEdit  -name "DQS_IS"        -parent TOPVBox4

    ui::addSpinBox  -name "FDC_EN_VAILD"   -parent TOPVBox4

    ui::addSpinBox  -name "CA_GROUP_NUM"   -parent TOPVBox4
    ui::addSpinBox  -name "REGION_NUM"     -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ0"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ1"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ2"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ3"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ4"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ5"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ6"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ7"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ8"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ9"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ10"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ11"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ12"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ13"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ14"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ15"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ16"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ17"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ18"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ19"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ20"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ21"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ22"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ23"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ24"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ25"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ26"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ27"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ28"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ29"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ30"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQ31"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQS0"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQSN0"       -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQS1"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQSN1"       -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQS2"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQSN2"       -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQS3"        -parent TOPVBox4
    ui::addTextEdit -name "PAD_DQSN3"       -parent TOPVBox4
    ui::addTextEdit -name "PAD_DM0"         -parent TOPVBox4
    ui::addTextEdit -name "PAD_DM1"         -parent TOPVBox4
    ui::addTextEdit -name "PAD_DM2"         -parent TOPVBox4
    ui::addTextEdit -name "PAD_DM3"         -parent TOPVBox4
    ui::addCheckBox -name "DQ0_EN"          -parent TOPVBox4
    ui::addCheckBox -name "DQ1_EN"          -parent TOPVBox4
    ui::addCheckBox -name "DQ2_EN"          -parent TOPVBox4
    ui::addCheckBox -name "DQ3_EN"          -parent TOPVBox4
    ui::addCheckBox -name "CS_N_EN"         -parent TOPVBox4
    ui::addCheckBox -name "BA2_EN"          -parent TOPVBox4
    ui::addCheckBox -name "A12_EN"          -parent TOPVBox4
    ui::addCheckBox -name "A13_EN"          -parent TOPVBox4
    ui::addCheckBox -name "A14_EN"          -parent TOPVBox4
    ui::addCheckBox -name "A15_EN"          -parent TOPVBox4
    ui::addCheckBox -name "DEBUG_EN"        -parent TOPVBox4
    ui::addCheckBox -name "CS_n_EN"         -parent TOPVBox4

    ui::addComboBox -name "DM_GROUP_EN"     -parent TOPVBox4

    ui::hide -name "CA_GROUP0"
    ui::hide -name "CA_GROUP1"
    ui::hide -name "CA_GROUP2"
    ui::hide -name "CA_GROUP3"
    ui::hide -name "CA_GROUP4"

    ui::hide -name "CA_GROUP0_REG"
    ui::hide -name "CA_GROUP1_REG"
    ui::hide -name "CA_GROUP2_REG"
    ui::hide -name "CA_GROUP3_REG"
    ui::hide -name "CA_GROUP4_REG"

    ui::hide -name "CA_GROUP_A0" 
    ui::hide -name "CA_GROUP_A1" 
    ui::hide -name "CA_GROUP_A2" 
    ui::hide -name "CA_GROUP_A3" 
    ui::hide -name "CA_GROUP_A4" 
    ui::hide -name "CA_GROUP_A5" 
    ui::hide -name "CA_GROUP_A6" 
    ui::hide -name "CA_GROUP_A7" 
    ui::hide -name "CA_GROUP_A8" 
    ui::hide -name "CA_GROUP_A9" 
    ui::hide -name "CA_GROUP_A10"
    ui::hide -name "CA_GROUP_A11"
    ui::hide -name "CA_GROUP_A12"
    ui::hide -name "CA_GROUP_A13"
    ui::hide -name "CA_GROUP_A14"
    ui::hide -name "CA_GROUP_A15"

    ui::hide -name "CA_GROUP_CKE"
    ui::hide -name "CA_GROUP_CK" 
    ui::hide -name "CA_GROUP_CS" 
    ui::hide -name "CA_GROUP_RAS"
    ui::hide -name "CA_GROUP_CAS"
    ui::hide -name "CA_GROUP_WE" 
    ui::hide -name "CA_GROUP_ODT"
    ui::hide -name "CA_GROUP_BA0"
    ui::hide -name "CA_GROUP_BA1"
    ui::hide -name "CA_GROUP_BA2"

    ui::hide -name "A0_REG_NUM" 
    ui::hide -name "A1_REG_NUM" 
    ui::hide -name "A2_REG_NUM" 
    ui::hide -name "A3_REG_NUM" 
    ui::hide -name "A4_REG_NUM" 
    ui::hide -name "A5_REG_NUM" 
    ui::hide -name "A6_REG_NUM" 
    ui::hide -name "A7_REG_NUM" 
    ui::hide -name "A8_REG_NUM" 
    ui::hide -name "A9_REG_NUM" 
    ui::hide -name "A10_REG_NUM"
    ui::hide -name "A11_REG_NUM"
    ui::hide -name "A12_REG_NUM"
    ui::hide -name "A13_REG_NUM"
    ui::hide -name "A14_REG_NUM"
    ui::hide -name "A15_REG_NUM"

    ui::hide -name "CKE_REG_NUM"
    ui::hide -name "CK_REG_NUM" 
    ui::hide -name "CS_REG_NUM" 
    ui::hide -name "RAS_REG_NUM"
    ui::hide -name "CAS_REG_NUM"
    ui::hide -name "WE_REG_NUM" 
    ui::hide -name "ODT_REG_NUM"
    ui::hide -name "BA0_REG_NUM"
    ui::hide -name "BA1_REG_NUM"
    ui::hide -name "BA2_REG_NUM"

    ui::hide -name "DQG_0_REG_NUM"
    ui::hide -name "DQG_1_REG_NUM"
    ui::hide -name "DQG_2_REG_NUM"
    ui::hide -name "DQG_3_REG_NUM"

    ui::hide -name "GROUP_DQG_0"
    ui::hide -name "GROUP_DQG_1"
    ui::hide -name "GROUP_DQG_2"
    ui::hide -name "GROUP_DQG_3"

    ui::hide -name "FDC_EN_VAILD"

    ui::hide -name "DEVICE_100H"

    ui::hide -name "MEM_BANK_WIDTH"
    ui::hide -name "MEM_ROW_WIDTH"
    ui::hide -name "MEM_ADDR_WIDTH"
    ui::hide -name "MEM_COLUMN_WIDTH"
    ui::hide -name "MEM_DM_WIDTH"
    ui::hide -name "MEM_DQS_WIDTH"
    ui::hide -name "CS_n_EN"
    ui::hide -name "DEBUG_EN"
    ui::hide -name "DM_GROUP_EN"
    ui::hide -name "CTRL_ADDR_WIDTH"

    ui::hide  -name "tREFI"
    ui::hide  -name "tRFC_MIN"
    ui::hide  -name "DFI_CLK_PERIOD"

    ui::hide  -name "DDR3_CWL"
    ui::hide  -name "DDR3_CL"
    ui::hide  -name "DDR3_AL"

    ui::hide  -name "DDR3_INIT_WR"
    ui::hide  -name "DDR3_CL_VALUE"
    ui::hide  -name "DDR3_WR"
    ui::hide  -name "PHY_TMRD"
    ui::hide  -name "PHY_TMOD"
    ui::hide  -name "PHY_TXPR"
    ui::hide  -name "PHY_TRP"
    ui::hide  -name "PHY_TRFC"
    ui::hide  -name "PHY_TRCD"
    ui::hide  -name "DDRC_TRFC"
    ui::hide  -name "DDRC_TREFI"
    ui::hide  -name "DDRC_T_FAW"
    ui::hide  -name "DDRC_T_RAS"
    ui::hide  -name "DDRC_T_XP"
    ui::hide  -name "DDRC_T_RC"
    ui::hide  -name "DDRC_T_RRD"
    ui::hide  -name "DDRC_T_RP"
    ui::hide  -name "DDRC_T_RCD"
    ui::hide  -name "DDRC_T_RTP"
    ui::hide  -name "DDRC_T_WR"
    ui::hide  -name "DDRC_T_WTR"

    ui::hide  -name "DDR_MEM_PART"
    ui::hide  -name "DESIRED_RATE"
    ui::hide  -name "ACTUAL_RATE"
    ui::hide  -name "STATIC_RATIOI"
    ui::hide  -name "STATIC_RATIOF"
    ui::hide  -name "STATIC_RATIO0"

    ui::hide -name "A0_GROUP_NUM"
    ui::hide -name "A1_GROUP_NUM"
    ui::hide -name "A2_GROUP_NUM"
    ui::hide -name "A3_GROUP_NUM"
    ui::hide -name "A4_GROUP_NUM"
    ui::hide -name "A5_GROUP_NUM"
    ui::hide -name "A6_GROUP_NUM"
    ui::hide -name "A7_GROUP_NUM"
    ui::hide -name "A8_GROUP_NUM"
    ui::hide -name "A9_GROUP_NUM"
    ui::hide -name "A10_GROUP_NUM"
    ui::hide -name "A11_GROUP_NUM"
    ui::hide -name "A12_GROUP_NUM"
    ui::hide -name "A13_GROUP_NUM"
    ui::hide -name "A14_GROUP_NUM"
    ui::hide -name "A15_GROUP_NUM"
    ui::hide -name "CKE_GROUP_NUM"
    ui::hide -name "CK_GROUP_NUM" 
    ui::hide -name "CS_GROUP_NUM"
    ui::hide -name "RAS_GROUP_NUM"
    ui::hide -name "CAS_GROUP_NUM"
    ui::hide -name "WE_GROUP_NUM"
    ui::hide -name "ODT_GROUP_NUM"
    ui::hide -name "BA0_GROUP_NUM"
    ui::hide -name "BA1_GROUP_NUM"
    ui::hide -name "BA2_GROUP_NUM"

    ui::hide -name "GROUP_DQG_0_NUM"
    ui::hide -name "GROUP_DQG_1_NUM"
    ui::hide -name "GROUP_DQG_2_NUM"
    ui::hide -name "GROUP_DQG_3_NUM"

    ui::hide -name "CA_GROUP_NUM"
    ui::hide -name "REGION_NUM"
    ui::hide -name "DQS_TEST"
    ui::hide -name "DQS_IS"
    ui::hide -name "PAD_DQ0"
    ui::hide -name "PAD_DQ1"
    ui::hide -name "PAD_DQ2"
    ui::hide -name "PAD_DQ3"
    ui::hide -name "PAD_DQ4"
    ui::hide -name "PAD_DQ5"
    ui::hide -name "PAD_DQ6"
    ui::hide -name "PAD_DQ7"
    ui::hide -name "PAD_DQ8"
    ui::hide -name "PAD_DQ9"
    ui::hide -name "PAD_DQ10"
    ui::hide -name "PAD_DQ11"
    ui::hide -name "PAD_DQ12"
    ui::hide -name "PAD_DQ13"
    ui::hide -name "PAD_DQ14"
    ui::hide -name "PAD_DQ15"
    ui::hide -name "PAD_DQ16"
    ui::hide -name "PAD_DQ17"
    ui::hide -name "PAD_DQ18"
    ui::hide -name "PAD_DQ19"
    ui::hide -name "PAD_DQ20"
    ui::hide -name "PAD_DQ21"
    ui::hide -name "PAD_DQ22"
    ui::hide -name "PAD_DQ23"
    ui::hide -name "PAD_DQ24"
    ui::hide -name "PAD_DQ25"
    ui::hide -name "PAD_DQ26"
    ui::hide -name "PAD_DQ27"
    ui::hide -name "PAD_DQ28"
    ui::hide -name "PAD_DQ29"
    ui::hide -name "PAD_DQ30"
    ui::hide -name "PAD_DQ31"
    ui::hide -name "PAD_DQS0"
    ui::hide -name "PAD_DQSN0"
    ui::hide -name "PAD_DQS1"
    ui::hide -name "PAD_DQSN1"
    ui::hide -name "PAD_DQS2"
    ui::hide -name "PAD_DQSN2"
    ui::hide -name "PAD_DQS3"
    ui::hide -name "PAD_DQSN3"
    ui::hide -name "PAD_DM0"
    ui::hide -name "PAD_DM1"
    ui::hide -name "PAD_DM2"
    ui::hide -name "PAD_DM3"

    ui::hide -name "DQ0_EN"
    ui::hide -name "DQ1_EN"
    ui::hide -name "DQ2_EN"
    ui::hide -name "DQ3_EN"
    ui::hide -name "CS_N_EN"
    ui::hide -name "BA2_EN"
    ui::hide -name "A12_EN"
    ui::hide -name "A13_EN"
    ui::hide -name "A14_EN"
    ui::hide -name "A15_EN"

    ui::addSpacer -p TOPVBox4

}

#create information
proc AddInfo {} {
    ui::addVBox -info -name mInfo
    ui::addTextEdit -info -text "
    DDR3 Interface
    " -name title -parent mInfo
}

proc ui::init {use_defaults} {

    CreateCfgLayout
    AddSymbolPins
    addMySynOption
    AddInfo
    pad_list_init
    if { $use_defaults == 1} {
        create_ip_update
    } else {
        reload_idf_update
    }
}

proc ui::update {args} {
    foreach arg $args {
        switch -exact $arg {
            "MEM_TYPE" {
                upd_mem_type_change
            }
            "OPERATING_MODE" {
                upd_operating_mode_change
            }
            "MEM_DQ_WIDTH" {
                upd_dq_width_change
            }
            "CLKIN_FREQ" -
            "DESIRED_DDR3_RATE" {
                upd_clock_change
            }
            "GUI_DDR3_AL" -
            "GUI_DDR3_CWL_800" -
            "GUI_DDR3_CL_800" {
                upd_write_read_latency
            }
            "Debug_Signals_En" {
                upd_debug_change
            }
            "CUSTOMIZE_MEM" {
                upd_create_custom_change
            }
            "DDR3_DFT_MEM_PART" -
            "DDR3_BASE_MEM_PART" {
                upd_mem_part_change
            }
            "DDR3_MEM_ROW_WIDTH" -
            "DDR3_MEM_COLUMN_WIDTH" -
            "DDR3_MEM_BANK_WIDTH" {
                upd_mem_addr_change
            }
            "DDR3_ODT_VALUE" -
            "DDR3_OUTPUT_DRIVER"  {
                upd_odt_odi_change
            }
            "MEM_BANK_WIDTH" -
            "MEM_DQS_WIDTH" -
            "MEM_DM_WIDTH" {
                upd_symbol_pins_width
            }
            "MEM_ADDR_WIDTH" {
                upd_addr_width_change
            }
            "USER_PINS_CON_EN" {
                upd_dft_pin_con_en_change
            }
            "USER_FDC_PATH" {
                upd_dft_fdc_path_change
            }
            "BANK_CA" {
                upd_bank_ca_change
            }
            "CS_n_En" {
                upd_ca_pin_en_change
            }
            "CUSTOMIZE_CA" {
                upd_custom_ca_change
            }
            "GROUP_CKE" {
                upd_pin_cke
            }
            "GROUP_CK" {
                upd_pin_ck
            }
            "GROUP_CKN" {
                upd_pin_ckn
            }
            "GROUP_CS" {
                upd_pin_cs
            }
            "GROUP_RAS" {
                upd_pin_ras
            }
            "GROUP_CAS" {
                upd_pin_cas
            }
            "GROUP_WE" {
                upd_pin_we
            }
            "GROUP_ODT" {
                upd_pin_odt
            }
            "GROUP_BA0" {
                upd_pin_ba0
            }
            "GROUP_BA1" {
                upd_pin_ba1
            }
            "GROUP_BA2" {
                upd_pin_ba2
            }
            "GROUP_A0" {
                upd_pin_a0
            }
            "GROUP_A1" {
                upd_pin_a1
            }
            "GROUP_A2" {
                upd_pin_a2
            }
            "GROUP_A3" {
                upd_pin_a3
            }
            "GROUP_A4" {
                upd_pin_a4
            }
            "GROUP_A5" {
                upd_pin_a5
            }
            "GROUP_A6" {
                upd_pin_a6
            }
            "GROUP_A7" {
                upd_pin_a7
            }
            "GROUP_A8" {
                upd_pin_a8
            }
            "GROUP_A9" {
                upd_pin_a9
            }
            "GROUP_A10" {
                upd_pin_a10
            }
            "GROUP_A11" {
                upd_pin_a11
            }
            "GROUP_A12" {
                upd_pin_a12
            }
            "GROUP_A13" {
                upd_pin_a13
            }
            "GROUP_A14" {
                upd_pin_a14
            }
            "GROUP_A15" {
                upd_pin_a15
            }
            "PAD_RESET" {
                pad_check "RESET" 0
            }
            "PAD_CKE" {
                pad_check "CKE" 1
            }
            "PAD_CK" {
                pad_check "CK" 2
            }
            "PAD_CKN" {
                pad_check "CKN" 3
            }
            "PAD_CS" {
                pad_check "CS" 4
            }
            "PAD_RAS" {
                pad_check "RAS" 5
            }
            "PAD_CAS" {
                pad_check "CAS" 6
            }
            "PAD_WE" {
                pad_check "WE" 7
            }
            "PAD_ODT" {
                pad_check "ODT" 8
            }
            "PAD_BA0" {
                pad_check "BA0" 9
            }
            "PAD_BA1" {
                pad_check "BA1" 10
            }
            "PAD_BA2" {
                pad_check "BA2" 11
            }
            "PAD_A0" {
                pad_check "A0" 12
            }
            "PAD_A1" {
                pad_check "A1" 13
            }
            "PAD_A2" {
                pad_check "A2" 14
            }
            "PAD_A3" {
                pad_check "A3" 15
            }
            "PAD_A4" {
                pad_check "A4" 16
            }
            "PAD_A5" {
                pad_check "A5" 17
            }
            "PAD_A6" {
                pad_check "A6" 18
            }
            "PAD_A7" {
                pad_check "A7" 19
            }
            "PAD_A8" {
                pad_check "A8" 20
            }
            "PAD_A9" {
                pad_check "A9" 21
            }
            "PAD_A10" {
                pad_check "A10" 22
            }
            "PAD_A11" {
                pad_check "A11" 23
            }
            "PAD_A12" {
                pad_check "A12" 24
            }
            "PAD_A13" {
                pad_check "A13" 25
            }
            "PAD_A14" {
                pad_check "A14" 26
            }
            "GROUP_DQG_0" -
            "GROUP_DQG_1" -
            "GROUP_DQG_2" -
            "GROUP_DQG_3" {
                upd_dq_group_change
            }
        }
    }
}


proc ui::check {} {

    global dq_bank_group_recfg

    set mem_clk [expr double([ui::getValue -name "ACTUAL_RATE"] / 2.0)]
    set mem_clk_period_ps [expr double(1000000.0 / $mem_clk)]
    set mem_clk_period_ns [expr double(1000.0 / $mem_clk)]
    set dfi_clk_period [expr double(4 * 1000000.0 / $mem_clk)]
    ui::setValue -name "DFI_CLK_PERIOD" -value [expr int(4 * 1000000.0 / $mem_clk)]

    if {[ui::getDevice] == "PGL25G"} {
        if {([ui::getPackage] != "FBG256") && ([ui::getPackage] != "MBG324") && ([ui::getPackage] != "FBG484")} { 
            set bSel [ui::popupMessage -w -t "Package read fail" \
                                       -m "The Package is not supported " \
                                       -b "Back"]
            if {$bSel == "Back"} {
                return 0
            } else {
                return 1
            }
        }
    } elseif {[ui::getDevice] == "PGL50H"} {
        if {([ui::getPackage] != "MBG484") && ([ui::getPackage] != "FBG484") && ([ui::getPackage] != "MBG324")} { 
            set bSel [ui::popupMessage -w -t "Package read fail" \
                                       -m "The Package is not supported " \
                                       -b "Back"]
            if {$bSel == "Back"} {
                return 0
            } else {
                return 1
            }
        }
    } elseif {[ui::getDevice] == "PGL50G"} {
        if {([ui::getPackage] != "MBG324") && ([ui::getPackage] != "FBG484") && ([ui::getPackage] != "MBG484") && ([ui::getPackage] != "FBG676")} { 
            set bSel [ui::popupMessage -w -t "Package read fail" \
                                       -m "The Package is not supported " \
                                       -b "Back"]
            if {$bSel == "Back"} {
                return 0
            } else {
                return 1
            }
        }
    } elseif {[ui::getDevice] == "PGL100H"} {
        if {[ui::getPackage] != "FBG900"} {
            set bSel [ui::popupMessage -w -t "Package read fail" \
                                       -m "The Package is not supported " \
                                       -b "Back"]
            if {$bSel == "Back"} {
                return 0
            } else {
                return 1
            }
        }
    }

    check_mr_ddr3_wr $mem_clk_period_ns
    check_mr_ddr3_cl
    check_timing_para $dfi_clk_period $mem_clk_period_ps
    check_ca_group_used
    check_ca_sig_group_num
    check_ca_dq_region_used
    check_ca_pin_group_region
    check_dq_group_number
    if {$dq_bank_group_recfg == 1} {
        check_pin_all_dq_dqs_dm
    }
    check_region_number
    check_dm_group_en
    check_device_100H
}

########################################################################################
################################### ui update proc #####################################
########################################################################################

proc create_ip_update {} {
    # step1
    upd_dq_width_option
    upd_operating_mode
    upd_data_rate
    upd_write_read_latency
    # step2
    upd_memory_part
    upd_show_custom_memory_part
    upd_ddr3_timing_trfc
    upd_ddr3_custom_addr
    upd_show_timing_para
    upd_show_address
    upd_show_output_driver
    # step3
    upd_show_dft_fdc_sel
    upd_read_fdc
    upd_auto_cfg_ca_dq_bank_group
    upd_show_customize_ca
    upd_pin_en
    upd_ca_group_pkg
    upd_show_ca
    upd_pin_ca
    upd_dq_group_pkg
    upd_show_dq
    upd_auto_cfg_ca_dq_pin
    upd_dq_bank_group_init
    # step4
    upd_summary_basic
    upd_summary_memory_option
    upd_summary_ca_bank
    upd_show_dq_txt
    # update symbol
    upd_symbol_pins_show
}

proc reload_idf_update {} {
    # step1
    upd_dq_width_option
    upd_operating_mode
    upd_data_rate
    upd_write_read_latency
    # step2
    upd_memory_part
    upd_show_custom_memory_part
    upd_show_timing_para
    upd_show_address
    upd_show_output_driver
    # step3
    upd_show_fdc_en_reload
    upd_show_customize_ca
    upd_pin_en
    upd_show_ca
    reassign_bank_group_ca_dq
    reassign_pin_ca
    upd_ca_group_pkg
    upd_pin_ca
    upd_dq_group_pkg
    reassign_bank_group_ca_dq
    reassign_pin_ca
    upd_show_dq 
    upd_dq_bank_group_init
    # step4
    upd_summary_basic
    upd_summary_memory_option
    upd_summary_ca_bank
    upd_show_dq_txt
    # update symbol
    upd_symbol_pins_show
}

proc upd_mem_type_change {} {
    # step1
    upd_dq_width_option
    upd_operating_mode
    upd_data_rate
    upd_write_read_latency
    # step2
    upd_memory_part
    upd_show_timing_para
    upd_show_address
    upd_show_output_driver
    # step3
    upd_dis_user_fdc_en
    upd_read_fdc
    upd_auto_cfg_ca_dq_bank_group
    upd_pin_en
    upd_show_ca
    upd_show_dq
    upd_auto_cfg_ca_dq_pin
    upd_dq_bank_group_init
    # step4
    upd_summary_basic
    upd_summary_memory_option
    upd_summary_ca_bank
    # update symbol
    upd_symbol_pins_show
}

proc upd_operating_mode_change {} {
    # step1
    # step2
    # step3
    # step4
    upd_summary_basic
    #update symbol
}

proc upd_dq_width_change {} {
    # step1
    upd_dqs_dm_width
    # step2
    # step3
    upd_show_dq
    # step4
    upd_summary_basic
    upd_summary_ca_bank
    upd_show_dq_txt
    # update symbol
    upd_symbol_pins_width
}

proc upd_clock_change {} {
    # step1
    upd_data_rate
    upd_write_read_latency
    # step2
    # step3
    # step4
    upd_summary_basic
}

proc upd_debug_change {} {
    # step1
    upd_debug_port_enable
    # step2
    # step3
    # step4
    upd_summary_basic
}

proc upd_create_custom_change {} {
    # step1
    # step2
    upd_memory_part
    upd_show_custom_memory_part
    #upd_ddr3_custom_addr
    # step3
    # step4
    upd_summary_memory_option
}

proc upd_mem_part_change {} {
    # step1
    # step2
    upd_memory_part
    upd_ddr3_timing_trfc
    upd_ddr3_custom_addr
    # step3
    # step4
    upd_summary_memory_option
    upd_summary_basic
}

proc upd_mem_addr_change {} {
    # step1
    # step2
    upd_ddr_addr_width
    # step3
    # step4
    upd_summary_memory_option
}

proc upd_addr_width_change {} {
    # step1
    # step2
    # step3
    upd_show_ca
    upd_show_dq
    # step4
    upd_show_dq_txt
    # update symbol
    upd_symbol_pins_width
}

proc upd_odt_odi_change {} {
    # step1
    # step2
    # step3
    # step4
    upd_summary_memory_option
}

proc upd_dft_pin_con_en_change {} {
    # step1
    # step2
    # step3
    upd_show_dft_fdc_sel
    # step4
    upd_summary_ca_bank
    upd_show_dq_txt
}

proc upd_dft_fdc_path_change {} {
    global sel_fdc_valid
    # step1
    # step2
    # step3
    upd_check_sel_fdc_vld
    if {$sel_fdc_valid == 1} {
        upd_read_fdc
        upd_auto_cfg_ca_dq_bank_group
        upd_show_ca
        upd_pin_ca
        upd_auto_cfg_ca_dq_pin
        upd_show_dq
        upd_dq_bank_group_init
        # step4
        upd_summary_ca_bank
        upd_show_dq_txt
    }
}

proc upd_bank_ca_change {} {
    # step1
    upd_dq_width_option
    # step2
    # step3
    pad_list_init
    pad_sel_update
    upd_check_sel_fdc_ca_bank
    if {[ui::getValue -name "FDC_EN_VAILD"]} {
        upd_ca_group_pkg
        upd_dq_group_pkg
        upd_read_fdc
        upd_auto_cfg_ca_dq_bank_group
        upd_show_ca
        upd_pin_ca
        upd_auto_cfg_ca_dq_pin
        upd_show_dq
        upd_dq_bank_group_init
    }     
    # step4
    upd_summary_ca_bank
    upd_show_dq_txt
}

proc upd_custom_ca_change {} {
    # step1
    # step2
    # step3
    upd_show_customize_ca
    # step4
}

proc upd_ca_pin_en_change {} {
    # step1
    # step2
    # step3
    upd_pin_en
    upd_show_ca
    # step4
    # update symbol
    upd_symbol_pins_show
}

proc upd_dq_group_change {} {
    # step1
    # step2
    # step3
    upd_dq_bank_group_recfg
    # step4
    # update symbol
}


################################### ui update sub proc #####################################

#step1
proc upd_dq_width_option {} {
    if {[ui::getDevice] == "PGL100H"} {
        ui::setItems -n "MEM_DQ_WIDTH" -items "32" "24" "16" "8"
    } elseif {[ui::getDevice] == "PGL50H"} {
        if {[ui::getPackage] == "MBG324"} {
            ui::setItems -n "MEM_DQ_WIDTH" -items "16" "8"
        } elseif {([ui::getPackage] == "FBG484") && ([ui::getValue -name "BANK_CA"] == "B1")} {
            ui::setItems -n "MEM_DQ_WIDTH" -items "16" "8"
        } else {
            ui::setItems -n "MEM_DQ_WIDTH" -items "32" "24" "16" "8"
        }
    } elseif {[ui::getDevice] == "PGL50G"} {
        if {[ui::getPackage] == "MBG324"} {
            ui::setItems -n "MEM_DQ_WIDTH" -items "16" "8"
        } elseif {([ui::getPackage] == "FBG484") && ([ui::getValue -name "BANK_CA"] == "B1")} {
            ui::setItems -n "MEM_DQ_WIDTH" -items "16" "8"
        } else {
            ui::setItems -n "MEM_DQ_WIDTH" -items "32" "24" "16" "8"
        }
    } elseif {[ui::getDevice] == "PGL25G"} {
        if {[ui::getPackage] == "FBG484"} {
            ui::setItems -n "MEM_DQ_WIDTH" -items "32" "24" "16" "8"
        } else {
            ui::setItems -n "MEM_DQ_WIDTH" -items "16" "8"
        }
    }
}

proc upd_dqs_dm_width {} {
    ui::setValue -name "MEM_DM_WIDTH" -value [expr [ui::getValue -name "MEM_DQ_WIDTH"]/8]
    ui::setValue -name "MEM_DQS_WIDTH" -value [expr [ui::getValue -name "MEM_DQ_WIDTH"]/8]
}

proc upd_operating_mode {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::enable -name "OPERATING_MODE"
        ui::setItems -n "OPERATING_MODE" -items "Controller + PHY"
    }
}

proc upd_data_rate {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::setText -name "data_rate_txt" -text "Mbps(range:600-800Mbps)"
        ui::show -name "DESIRED_DDR3_RATE"
        ui::setValue -name "DESIRED_RATE" -value [ui::getValue -name "DESIRED_DDR3_RATE"]
    }
    upd_pll_rate
}

proc upd_pll_rate {} {
    global idiv
    global fdiv
    global odiv
    global vco_freq
    global act_clkout_freq

    set clkout_req [expr double([ui::getValue -name "DESIRED_RATE"])/2.00]
    createDivideParam [ui::getValue -name "CLKIN_FREQ"] $clkout_req
    ui::setValue -name "STATIC_RATIOF" -value "$fdiv"
    ui::setValue -name "STATIC_RATIOI" -value "$idiv"
    ui::setValue -name "STATIC_RATIO0" -value "$odiv"
    ui::setValue -name "ACTUAL_RATE" -value [expr double(2 * double($vco_freq)/double($odiv))]
    ui::setText -name "ACTUAL_RATE_txt" -text "[ui::getValue -name "ACTUAL_RATE"]"
}

proc upd_write_read_latency {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "page1_ddr3_seting6"
        # update CWL and CL
        ui::setText -name "DDR3_CWL_TXT" -text "tCK(range: 5)"
        ui::setText -name "DDR3_CL_TXT" -text "tCK(range: 5-6)"
        ui::setValue -name "DDR3_CWL" -value [ui::getValue -name "GUI_DDR3_CWL_800"]
        ui::setValue -name "DDR3_CL" -value [ui::getValue -name "GUI_DDR3_CL_800"]
        # update AL
        if {[ui::getValue -name "GUI_DDR3_AL"] == "0"} {
            ui::setValue -name "DDR3_AL" -value 0
        } elseif {[ui::getValue -name "GUI_DDR3_AL"] == "CL-2"} {
            ui::setValue -name "DDR3_AL" -value 2
        }
    }
}

proc upd_debug_port_enable {} {
    if {[ui::getValue -name "Debug_Signals_En"]} {
        ui::setValue -name "DEBUG_EN" -value 1
    } else {
        ui::setValue -name "DEBUG_EN" -value 0
    }
}

# step2
proc upd_memory_part {} {
    if {[ui::getValue -name "CUSTOMIZE_MEM"] == 0} {
        if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
            ui::show -name "DDR3_DFT_MEM_PART"
            ui::show -name "DDR3_BASE_MEM_PART"
            ui::setValue -name "DDR_MEM_PART" -value [ui::getValue -name "DDR3_DFT_MEM_PART"]
        }
        ui::enable -name "DDR3_DFT_MEM_PART"
    } elseif {[ui::getValue -name "CUSTOMIZE_MEM"] == 1} {
        if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
            ui::show -name "DDR3_DFT_MEM_PART"
            ui::show -name "DDR3_BASE_MEM_PART"
            ui::setValue -name "DDR_MEM_PART" -value [ui::getValue -name "DDR3_BASE_MEM_PART"]
        }
        ui::disable -name "DDR3_DFT_MEM_PART"
    }
}

proc upd_show_custom_memory_part {} {
    if {[ui::getValue -name "CUSTOMIZE_MEM"] == 1} {
        ui::show -name "page2_seting2"
    } else {
        ui::hide -name "page2_seting2"
    }
}

proc upd_show_timing_para {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "page2_ddr3_seting"
    }
}

proc upd_show_address {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "page2_ddr3ad_seting"
    }
    upd_ddr_addr_width
}

proc upd_show_output_driver {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "DDR3_OUT"
        ui::show -name "DDR3_ODT"
    }
}

# if memory part change, operate this proc.
proc upd_ddr3_default_timing_trfc {} {
    if {[ui::getValue -name "DDR3_DFT_MEM_PART"] == "MT41J128M8xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 110
    } elseif {[ui::getValue -name "DDR3_DFT_MEM_PART"] == "MT41J128M16xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 160
    } elseif {[ui::getValue -name "DDR3_DFT_MEM_PART"] == "MT41J64M16xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 110
    } elseif {[ui::getValue -name "DDR3_DFT_MEM_PART"] == "MT41J256M8xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 160
    } elseif {[ui::getValue -name "DDR3_DFT_MEM_PART"] == "MT41K256M16xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 300
    }
}

proc upd_ddr3_custom_timing_trfc {} {
    if {[ui::getValue -name "DDR3_BASE_MEM_PART"] == "MT41J128M8xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 110
    } elseif {[ui::getValue -name "DDR3_BASE_MEM_PART"] == "MT41J128M16xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 160
    } elseif {[ui::getValue -name "DDR3_BASE_MEM_PART"] == "MT41J64M16xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 110
    } elseif {[ui::getValue -name "DDR3_BASE_MEM_PART"] == "MT41J256M8xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 160
    } elseif {[ui::getValue -name "DDR3_BASE_MEM_PART"] == "MT41K256M16xx-15E"} {
        ui::setValue -name "GUI_DDR3_TRFC" -value 300
    }
}

proc upd_ddr3_timing_trfc {} {
    if {[ui::getValue -name "CUSTOMIZE_MEM"] == 1} {
        upd_ddr3_custom_timing_trfc
    } else {
        upd_ddr3_default_timing_trfc
    }
}

proc upd_ddr3_custom_addr {} {
    if {[ui::getValue -name "DDR_MEM_PART"] == "MT41J128M8xx-15E"} {
        ui::setValue -name "DDR3_MEM_ROW_WIDTH" -value 14
        ui::setValue -name "DDR3_MEM_COLUMN_WIDTH" -value 10
        ui::setValue -name "DDR3_MEM_BANK_WIDTH" -value 3
    } elseif {[ui::getValue -name "DDR_MEM_PART"] == "MT41J128M16xx-15E"} {
        ui::setValue -name "DDR3_MEM_ROW_WIDTH" -value 14
        ui::setValue -name "DDR3_MEM_COLUMN_WIDTH" -value 10
        ui::setValue -name "DDR3_MEM_BANK_WIDTH" -value 3
    } elseif {[ui::getValue -name "DDR_MEM_PART"] == "MT41J64M16xx-15E"} {
        ui::setValue -name "DDR3_MEM_ROW_WIDTH" -value 13
        ui::setValue -name "DDR3_MEM_COLUMN_WIDTH" -value 10
        ui::setValue -name "DDR3_MEM_BANK_WIDTH" -value 3
    } elseif {[ui::getValue -name "DDR_MEM_PART"] == "MT41J256M8xx-15E"} {
        ui::setValue -name "DDR3_MEM_ROW_WIDTH" -value 15
        ui::setValue -name "DDR3_MEM_COLUMN_WIDTH" -value 10
        ui::setValue -name "DDR3_MEM_BANK_WIDTH" -value 3
    } elseif {[ui::getValue -name "DDR_MEM_PART"] == "MT41K256M16xx-15E"} {
        ui::setValue -name "DDR3_MEM_ROW_WIDTH" -value 15
        ui::setValue -name "DDR3_MEM_COLUMN_WIDTH" -value 10
        ui::setValue -name "DDR3_MEM_BANK_WIDTH" -value 3
    }
}

proc upd_ddr_addr_width {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::setValue -name "MEM_ROW_WIDTH" -value [ui::getValue -name "DDR3_MEM_ROW_WIDTH"]
        ui::setValue -name "MEM_ADDR_WIDTH" -value [ui::getValue -name "DDR3_MEM_ROW_WIDTH"]
        ui::setValue -name "MEM_COLUMN_WIDTH" -value [ui::getValue -name "DDR3_MEM_COLUMN_WIDTH"]
        ui::setValue -name "MEM_BANK_WIDTH" -value [ui::getValue -name "DDR3_MEM_BANK_WIDTH"]
        ui::setValue -name "CTRL_ADDR_WIDTH" -value [expr [ui::getValue -name "DDR3_MEM_ROW_WIDTH"]+[ui::getValue -name "DDR3_MEM_COLUMN_WIDTH"]+[ui::getValue -name "DDR3_MEM_BANK_WIDTH"]]

    }
}

# step3: pin/bank options

proc upd_dis_user_fdc_en {} {
    ui::setValue -name "USER_PINS_CON_EN" -value 0
    ui::hide -name "USER_FDC_PATH"
    ui::setText -name "USER_FDC_PATH" -text "Please select a fdc file"
}

proc upd_read_fdc {} {
    global mem_par_dq_bank_list
    global mem_par_ca_group_list
    global mem_par_dq_group_list
    global mem_par_ca_pin_list
    global mem_par_dq_pin_list
    global mem_prj_ca_pin_list
    global mem_prj_dq_pin_list
    global find_pin_list

    set path_ip [ui::getModelPath]

    if {[ui::getValue -name "USER_PINS_CON_EN"]} {
        set user_fdc_file [open [ui::getValue -name "USER_FDC_PATH"] r]
    } elseif {[ui::getDevice] == "PGL25G"} {
        if {[ui::getPackage] == "FBG256"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/25g_ddr3_256_b1_x16.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/25g_ddr3_256_b3_x16.fdc r]
            }
        } elseif {[ui::getPackage] == "MBG324"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/25g_ddr3_324_b1_x16.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/25g_ddr3_324_b3_x16.fdc r]
            }
        } elseif {[ui::getPackage] == "FBG484"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/25g_ddr3_484_b1_x32.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/25g_ddr3_484_b3_x32.fdc r]
            }
        }
    } elseif {[ui::getDevice] == "PGL50H"} {
        if {[ui::getPackage] == "MBG324"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/50h_ddr3_mbg324_b1_x16.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/50h_ddr3_mbg324_b3_x16.fdc r]
            }
        } elseif {[ui::getPackage] == "MBG484"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/50h_ddr3_mbg484_b1_x32.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/50h_ddr3_mbg484_b3_x32.fdc r]
            }
        } elseif {[ui::getPackage] == "FBG484"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/50h_ddr3_fbg484_b1_x16.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/50h_ddr3_fbg484_b3_x32.fdc r]
            }
        }
    } elseif {[ui::getDevice] == "PGL50G"} {
        if {[ui::getPackage] == "MBG324"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/50g_ddr3_mbg324_b1_x16.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/50g_ddr3_mbg324_b3_x16.fdc r]
            }
        } elseif {[ui::getPackage] == "MBG484"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/50g_ddr3_mbg484_b1_x32.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/50g_ddr3_mbg484_b3_x32.fdc r]
            }
        } elseif {[ui::getPackage] == "FBG484"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/50g_ddr3_fbg484_b1_x16.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/50g_ddr3_fbg484_b3_x32.fdc r]
            }
        } elseif {[ui::getPackage] == "FBG676"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/50g_ddr3_fbg676_b1_x32.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/50g_ddr3_fbg676_b3_x32.fdc r]
            }
        }
    } elseif {[ui::getDevice] == "PGL100H"} {
        if {[ui::getPackage] == "FBG900"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                set user_fdc_file [open $path_ip/pnr/100h_ddr3_900_b1_x32.fdc r]
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                set user_fdc_file [open $path_ip/pnr/100h_ddr3_900_b3_x32.fdc r]
            }
        }
    }

    set mem_par_ca_group_list [list GROUP_CK GROUP_CKN \
                                    GROUP_CKE GROUP_CS GROUP_RAS GROUP_CAS GROUP_WE \
                                    GROUP_ODT \
                                    GROUP_BA0 GROUP_BA1 GROUP_BA2 \
                                    GROUP_A0 GROUP_A1 GROUP_A2 GROUP_A3 GROUP_A4 GROUP_A5 GROUP_A6 GROUP_A7 GROUP_A8 \
                                    GROUP_A9 GROUP_A10 GROUP_A11 GROUP_A12 GROUP_A13 GROUP_A14 GROUP_A15]

    set mem_par_dq_group_list [list GROUP_DQG_0 GROUP_DQG_1 GROUP_DQG_2 GROUP_DQG_3]

    set mem_par_ca_pin_list [list PAD_CK PAD_CKN \
                                  PAD_CKE PAD_CS PAD_RAS PAD_CAS PAD_WE \
                                  PAD_ODT \
                                  PAD_BA0 PAD_BA1 PAD_BA2 \
                                  PAD_A0 PAD_A1 PAD_A2 PAD_A3 PAD_A4 PAD_A5 PAD_A6 PAD_A7 PAD_A8 \
                                  PAD_A9 PAD_A10 PAD_A11 PAD_A12 PAD_A13 PAD_A14 PAD_A15 \
                                  PAD_RESET]

    set mem_par_dq_pin_list [list PAD_DQS0    PAD_DQS1    PAD_DQS2    PAD_DQS3  \
                                  PAD_DQSN0   PAD_DQSN1   PAD_DQSN2   PAD_DQSN3 \
                                  PAD_DM0     PAD_DM1     PAD_DM2     PAD_DM3   \
                                  PAD_DQ0     PAD_DQ1     PAD_DQ2     PAD_DQ3     PAD_DQ4     PAD_DQ5     PAD_DQ6     PAD_DQ7  \
                                  PAD_DQ8     PAD_DQ9     PAD_DQ10    PAD_DQ11    PAD_DQ12    PAD_DQ13    PAD_DQ14    PAD_DQ15 \
                                  PAD_DQ16    PAD_DQ17    PAD_DQ18    PAD_DQ19    PAD_DQ20    PAD_DQ21    PAD_DQ22    PAD_DQ23 \
                                  PAD_DQ24    PAD_DQ25    PAD_DQ26    PAD_DQ27    PAD_DQ28    PAD_DQ29    PAD_DQ30    PAD_DQ31]

    set mem_prj_ca_pin_list [list mem_ck mem_ck_n \
                                  mem_cke mem_cs_n mem_ras_n mem_cas_n mem_we_n \
                                  mem_odt \
                                  mem_ba\[0\] mem_ba\[1\] mem_ba\[2\] \
                                  mem_a\[0\] mem_a\[1\] mem_a\[2\] mem_a\[3\] mem_a\[4\] mem_a\[5\] mem_a\[6\] mem_a\[7\] mem_a\[8\] \
                                  mem_a\[9\] mem_a\[10\] mem_a\[11\] mem_a\[12\] mem_a\[13\] mem_a\[14\] mem_a\[15\] \
                                  mem_rst_n]

    set mem_prj_dq_pin_list [list mem_dqs\[0\]     mem_dqs\[1\]     mem_dqs\[2\]     mem_dqs\[3\]   \
                                  mem_dqs_n\[0\]   mem_dqs_n\[1\]   mem_dqs_n\[2\]   mem_dqs_n\[3\] \
                                  mem_dm\[0\]      mem_dm\[1\]      mem_dm\[2\]      mem_dm\[3\]    \
                                  mem_dq\[0\]      mem_dq\[1\]      mem_dq\[2\]      mem_dq\[3\]      mem_dq\[4\]      mem_dq\[5\]      mem_dq\[6\]      mem_dq\[7\]  \
                                  mem_dq\[8\]      mem_dq\[9\]      mem_dq\[10\]     mem_dq\[11\]     mem_dq\[12\]     mem_dq\[13\]     mem_dq\[14\]     mem_dq\[15\] \
                                  mem_dq\[16\]     mem_dq\[17\]     mem_dq\[18\]     mem_dq\[19\]     mem_dq\[20\]     mem_dq\[21\]     mem_dq\[22\]     mem_dq\[23\] \
                                  mem_dq\[24\]     mem_dq\[25\]     mem_dq\[26\]     mem_dq\[27\]     mem_dq\[28\]     mem_dq\[29\]     mem_dq\[30\]     mem_dq\[31\] ]

    set find_pin_list [list ]

    while {[gets $user_fdc_file file_line] > -1} {
        # find PAP_IO_LOC line
        if {[regexp {^\ *define_attribute\ +\{p:([a-z0-9_\[\]]+)\}\ +\{PAP_IO_LOC\}\ +\{([A-Z0-9]+)\}} $file_line match_string io_name io_loc]} {
            lappend find_pin_list [list $io_name $io_loc]
        }
    }
    close $user_fdc_file
}

proc upd_auto_cfg_ca_dq_bank_group {} {
    global mem_par_ca_group_list
    global mem_par_dq_group_list
    global mem_prj_ca_pin_list
    global mem_prj_dq_pin_list
    global find_pin_list

    foreach pin_loc $find_pin_list {
        # cfg ca bank
        if {[lindex $pin_loc 0] == "mem_ck"} {
            ui::setValue -name "BANK_CA" -value [ui::getPkgPinBank -name [lindex $pin_loc 1]]
        }
        # cfg ca group
        set pin_in_prj_ca_pin_list_idx [lsearch -exact $mem_prj_ca_pin_list [lindex $pin_loc 0]]
        set pin_in_prj_dq_pin_list_idx [lsearch -exact $mem_prj_dq_pin_list [lindex $pin_loc 0]]
        if {$pin_in_prj_ca_pin_list_idx != -1} {
            if {[lindex $mem_par_ca_group_list $pin_in_prj_ca_pin_list_idx] != ""} {
                ui::setValue -name [lindex $mem_par_ca_group_list $pin_in_prj_ca_pin_list_idx] -value [ui::getPkgPinGroup -name [lindex $pin_loc 1]]
            }
        } elseif {$pin_in_prj_dq_pin_list_idx != -1} {
            if {[lindex $mem_par_dq_group_list $pin_in_prj_dq_pin_list_idx] != ""} {
                # cfg dq group
                ui::setValue -name [lindex $mem_par_dq_group_list $pin_in_prj_dq_pin_list_idx] -value [ui::getPkgPinGroup -name [lindex $pin_loc 1]]
            }
        }
    }
}

proc upd_auto_cfg_ca_dq_pin {} {
    global mem_par_ca_pin_list
    global mem_par_dq_pin_list
    global mem_prj_ca_pin_list
    global mem_prj_dq_pin_list
    global find_pin_list

    foreach pin_loc $find_pin_list {
        set pin_in_prj_ca_pin_list_idx [lsearch -exact $mem_prj_ca_pin_list [lindex $pin_loc 0]]
        set pin_in_prj_dq_pin_list_idx [lsearch -exact $mem_prj_dq_pin_list [lindex $pin_loc 0]]
        if {$pin_in_prj_ca_pin_list_idx != -1} {
            if {[lindex $mem_par_ca_pin_list $pin_in_prj_ca_pin_list_idx] != ""} {
                ui::setValue -name [lindex $mem_par_ca_pin_list $pin_in_prj_ca_pin_list_idx] -value [lindex $pin_loc 1]
            }
        } elseif {$pin_in_prj_dq_pin_list_idx != -1} {
            if {[lindex $mem_par_dq_pin_list $pin_in_prj_dq_pin_list_idx] != ""} {
                ui::setValue -name [lindex $mem_par_dq_pin_list $pin_in_prj_dq_pin_list_idx] -value [lindex $pin_loc 1]
            }
        }
    }
}

proc upd_show_fdc_en_reload {} {
    if {[ui::getValue -name "USER_PINS_CON_EN"]} {
        ui::show -name "USER_FDC_PATH"
        ui::show -name "USER_FDC_BROWSE"
        ui::disable -name "BANK_CA"
    } else {
        ui::hide -name "USER_FDC_PATH"
        ui::hide -name "USER_FDC_BROWSE"
        ui::enable -name "BANK_CA"
        ui::setText -name "USER_FDC_PATH" -text "Please select a fdc file"
    }
}

proc upd_show_dft_fdc_sel {} {
    if {[ui::getValue -name "USER_PINS_CON_EN"]} {
        ui::show -name "USER_FDC_PATH"
        ui::show -name "USER_FDC_BROWSE"
        ui::disable -name "BANK_CA"
    } else {
        ui::hide -name "USER_FDC_PATH"
        ui::hide -name "USER_FDC_BROWSE"
        ui::enable -name "BANK_CA"
        ui::setText -name "USER_FDC_PATH" -text "Please select a fdc file"
        upd_read_fdc
        upd_auto_cfg_ca_dq_bank_group
        upd_show_ca
        upd_pin_ca
        upd_auto_cfg_ca_dq_pin
        upd_show_dq
        upd_dq_bank_group_init
    }
}

proc upd_check_sel_fdc_vld {} {
    global sel_fdc_valid
    set fdc_path [ui::getValue -name "USER_FDC_PATH"]
    if {[file exists $fdc_path] == 0} {
        set sel_fdc_valid 0
        ui::popupBalloon -name "USER_FDC_PATH" -message "Error: Can't find \"${fdc_path}\"!"
    } elseif {[regexp {\.fdc$} $fdc_path]} {
        set sel_fdc_valid 1
    } else {
        set sel_fdc_valid 0
        ui::popupBalloon -name "USER_FDC_PATH" -message "Error: Selected file is not a fdc file!"
    }
}

proc upd_check_sel_fdc_ca_bank {} {
    set fdc_path [ui::getValue -name "USER_FDC_PATH"]
    ui::setValue -name "FDC_EN_VAILD" -value 1
    if {[ui::getValue -name "USER_PINS_CON_EN"]} {
        if {[regexp {\.fdc$} $fdc_path] == 0} {
            ui::setValue -name "FDC_EN_VAILD" -value 0
            set bSel [ui::popupMessage -w -t "fdc read fail" \
                                          -m "Please select a correct fdc file" \
                                          -b "Back"]
        }
    }
}

proc upd_show_customize_ca {} {
    if {[ui::getValue -name "CUSTOMIZE_CA"] == 0} {
        ui::hide -name ca_group_seting1
        ui::hide -name "NOTE_CA"
    } else {
        ui::show -name ca_group_seting1
        ui::show -name "NOTE_CA"
    }
}

proc upd_pin_en {} {
    if { [ui::getValue -name "CS_n_En" ] } {
        ui::setValue -name "CS_n_EN" -value 1
        ui::setText -name "CS_n_txt" -t ": Enabled"
    } else {
        ui::setValue -name "CS_n_EN" -value 0
        ui::setText -name "CS_n_txt" -t ": Disabled"
    }
}

proc upd_ca_group_pkg {} {
    set ca_group_pkg_list [list "CKE" "ODT" "CK" "CKN" "BA0" "BA1" "BA2" "CS" "RAS" "CAS" "WE" "A0" "A1" "A2" "A3" "A4" "A5" "A6" "A7" "A8" "A9" "A10" "A11" "A12" "A13" "A14"]

    foreach ca_group_pkg $ca_group_pkg_list {
        if {[ui::getDevice] == "PGL25G"} {
            ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5"
        } elseif {[ui::getDevice] == "PGL50H"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                if {[ui::getPackage] == "MBG324"} {
                    ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G2" "G3" "G4" "G5" "G6"
                } else {
                    ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7"
                }
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                if {[ui::getPackage] == "MBG324"} {
                    ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G2" "G3" "G4" "G5" "G8"
                } else {
                    ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8"
                }
            }
        } elseif {[ui::getDevice] == "PGL50G"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                if {[ui::getPackage] == "MBG324"} {
                    ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G2" "G3" "G4" "G5" "G6"
                } else {
                    ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7"
                }
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                if {[ui::getPackage] == "MBG324"} {
                    ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G2" "G3" "G4" "G5" "G8"
                } else {
                    ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8"
                }
            }
        } elseif {[ui::getDevice] == "PGL100H"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                ui::setItems -n "GROUP_$ca_group_pkg" -items "G1" "G2" "G3" "G4" "G5" "G6" "G7"
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                ui::setItems -n "GROUP_$ca_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8"
            }
        }
    }
}

proc pad_list_init {} {
    global all_pad_list
    set all_pad_list [list [list "RESET" 0 1] [list "CKE" 0 1] [list "CK" 0 1] [list "CKN" 0 1] [list "CS" 0 1] [list "RAS" 0 1] [list "CAS" 0 1] [list "WE" 0 1] [list "ODT" 0 1] [list "BA0" 0 1] [list "BA1" 0 1] [list "BA2" 0 1] [list "A0" 0 1] [list "A1" 0 1] [list "A2" 0 1] [list "A3" 0 1] [list "A4" 0 1] [list "A5" 0 1] [list "A6" 0 1] [list "A7" 0 1] [list "A8" 0 1] [list "A9" 0 1] [list "A10" 0 1] [list "A11" 0 1] [list "A12" 0 1] [list "A13" 0 1] [list "A14" 0 1]]
}

proc pad_sel_update {} {
    global all_pad_list
    set check_list [list "RESET" "CKE" "CK" "CKN" "CS" "RAS" "CAS" "WE" "ODT" "BA0" "BA1" "BA2" "A0" "A1" "A2" "A3" "A4" "A5" "A6" "A7" "A8" "A9" "A10" "A11" "A12" "A13" "A14"]

    pad_black_check $check_list
    pad_all_check $check_list
    pad_color_check
}

proc pad_check {pad_name i} {
    global all_pad_list
    set check_list [list "RESET" "CKE" "CK" "CKN" "CS" "RAS" "CAS" "WE" "ODT" "BA0" "BA1" "BA2" "A0" "A1" "A2" "A3" "A4" "A5" "A6" "A7" "A8" "A9" "A10" "A11" "A12" "A13" "A14"]

    pad_red_check $check_list $pad_name $i
    pad_black_check $check_list
    pad_red_check $check_list $pad_name $i
    pad_color_check
}

proc pad_black_check {check_list} {
    set k 0
    global all_pad_list

    foreach list_value_r $check_list {
        set row_pad_list [lindex $all_pad_list $k]
        set row_pad_name [lindex $row_pad_list 0]
        set row_pad_color [lindex $row_pad_list 1]
        set row_pad_show [lindex $row_pad_list 2]
        if {$row_pad_show == 1} {
            if {$row_pad_color == 1} {
                set i 0
                set all_pad_list [lreplace $all_pad_list $k $k [list $row_pad_name 0 1]]
                foreach list_value_c $check_list {
                    set col_pad_list [lindex $all_pad_list $i]
                    set col_pad_name [lindex $col_pad_list 0]
                    set col_pad_show [lindex $col_pad_list 2]
                    if {$row_pad_name != $col_pad_name} {
                        if {$col_pad_show == 1} {
                            if {[ui::getValue -name "PAD_${row_pad_name}"] == [ui::getValue -name "PAD_${col_pad_name}"]} {
                                set all_pad_list [lreplace $all_pad_list $k $k [list $row_pad_name 1 1]]
                                set all_pad_list [lreplace $all_pad_list $i $i [list $col_pad_name 1 1]]
                            }
                        }
                    }
                    incr i 1
                }
            }
        }
        incr k 1
    }
}

proc pad_all_check {check_list} {
    set p 0
    global all_pad_list

    foreach list_value_r $check_list {
        set row_pad_list [lindex $all_pad_list $p]
        set row_pad_name [lindex $row_pad_list 0]
        set row_pad_show [lindex $row_pad_list 2]
        if {$row_pad_show == 1} {
            set i 0
            foreach list_value_c $check_list {
                set col_pad_list [lindex $all_pad_list $i]
                set col_pad_name [lindex $col_pad_list 0]
                set col_pad_show [lindex $col_pad_list 2]
                if {$row_pad_name != $col_pad_name} {
                    if {$col_pad_show == 1} {
                        if {[ui::getValue -name "PAD_${row_pad_name}"] == [ui::getValue -name "PAD_${col_pad_name}"]} {
                            set all_pad_list [lreplace $all_pad_list $p $p [list $row_pad_name 1 1]]
                            set all_pad_list [lreplace $all_pad_list $i $i [list $col_pad_name 1 1]]
                        }
                    }
                }
                incr i 1
            }
        }
        incr p 1
    }
}

proc pad_red_check {check_list pad_name i} {
    set j 0
    global all_pad_list

    foreach list_value $check_list {
        set check_pad_list [lindex $all_pad_list $j]
        set check_pad_name [lindex $check_pad_list 0]
        set check_pad_color [lindex $check_pad_list 1]
        set check_pad_show [lindex $check_pad_list 2]
        if {$check_pad_show == 1} {
            if {$pad_name != $check_pad_name} {
                if {[ui::getValue -name "PAD_${pad_name}"] == [ui::getValue -name "PAD_${list_value}"]} {
                    set all_pad_list [lreplace $all_pad_list $j $j [list $check_pad_name 1 1]]
                    set all_pad_list [lreplace $all_pad_list $i $i [list $pad_name 1 1]]
                }
            }
        }
        incr j 1
    }
}

proc pad_color_check {} {
    set m 0
    global all_pad_list

    while {$m <= 26} {
        set pad_list [lindex $all_pad_list $m]
        set pad_n [lindex $pad_list 0]
        set pad_color [lindex $pad_list 1]
        set pad_show [lindex $pad_list 2]
        if {$pad_color == 0} {
            ui::resetColor -name "PAD_${pad_n}"
        } else {
            ui::setColor -name "PAD_${pad_n}" -color red
        }
        incr m 1
    }
}

proc upd_show_ca {} {
    upd_show_cs
    upd_show_ras
    upd_show_cas
    upd_show_we
    upd_show_ba2
    upd_show_a12
    upd_show_a13
    upd_show_a14
    upd_show_a15
    pad_sel_update
}

proc upd_show_cs {} {
    global all_pad_list
    set update_list [lindex $all_pad_list 4]
    set j [lindex $update_list 1]
    if {[ui::getValue -name "CS_n_EN"]} {
        ui::show -name "CS_txt"
        ui::show -name "GROUP_CS"
        ui::show -name "PAD_CS"
        ui::setValue -name "CS_N_EN" -value 1
        set i 1
    } else {
        ui::hide -name "CS_txt"
        ui::hide -name "GROUP_CS"
        ui::hide -name "PAD_CS"
        ui::setValue -name "CS_N_EN" -value 0
        set i 0
    }
    set all_pad_list [lreplace $all_pad_list 4 4 [list "CS" $j $i]]
}

proc upd_show_ras {} {
    global all_pad_list
    set update_list [lindex $all_pad_list 5]
    set j [lindex $update_list 1]
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "RAS_txt"
        ui::show -name "GROUP_RAS"
        ui::show -name "PAD_RAS"
        set i 1
    } else {
        ui::hide -name "RAS_txt"
        ui::hide -name "GROUP_RAS"
        ui::hide -name "PAD_RAS"
        set i 0
    }
    set all_pad_list [lreplace $all_pad_list 5 5 [list "RAS" $j $i]]
}

proc upd_show_cas {} {
    global all_pad_list
    set update_list [lindex $all_pad_list 6]
    set j [lindex $update_list 1]
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "CAS_txt"
        ui::show -name "GROUP_CAS"
        ui::show -name "PAD_CAS"
        set i 1
    } else {
        ui::hide -name "CAS_txt"
        ui::hide -name "GROUP_CAS"
        ui::hide -name "PAD_CAS"
        set i 0
    }
    set all_pad_list [lreplace $all_pad_list 6 6 [list "CAS" $j $i]]
}

proc upd_show_we {} {
    global all_pad_list
    set update_list [lindex $all_pad_list 7]
    set j [lindex $update_list 1]
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "WE_txt"
        ui::show -name "GROUP_WE"
        ui::show -name "PAD_WE"
        set i 1
    } else {
        ui::hide -name "WE_txt"
        ui::hide -name "GROUP_WE"
        ui::hide -name "PAD_WE"
        set i 0
    }
    set all_pad_list [lreplace $all_pad_list 7 7 [list "WE" $j $i]]
}

proc upd_show_ba2 {} {
    global all_pad_list
    set update_list [lindex $all_pad_list 11]
    set j [lindex $update_list 1]
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "BA2_txt"
        ui::show -name "GROUP_BA2"
        ui::show -name "PAD_BA2"
        ui::setValue -name "BA2_EN" -value 1
        set i 1
    } else {
        ui::hide -name "BA2_txt"
        ui::hide -name "GROUP_BA2"
        ui::hide -name "PAD_BA2"
        ui::setValue -name "BA2_EN" -value 0
        set i 0
    }
    set all_pad_list [lreplace $all_pad_list 11 11 [list "BA2" $j $i]]
}

proc upd_show_a12 {} {
    global all_pad_list
    set update_list [lindex $all_pad_list 24]
    set j [lindex $update_list 1]
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 13} {
        ui::show -name "A12_txt"
        ui::show -name "GROUP_A12"
        ui::show -name "PAD_A12"
        ui::setValue -name "A12_EN" -value 1
        set i 1
    } else {
        ui::hide -name "A12_txt"
        ui::hide -name "GROUP_A12"
        ui::hide -name "PAD_A12"
        ui::setValue -name "A12_EN" -value 0
        set i 0
    }
    set all_pad_list [lreplace $all_pad_list 24 24 [list "A12" $j $i]]
}

proc upd_show_a13 {} {
    global all_pad_list
    set update_list [lindex $all_pad_list 25]
    set j [lindex $update_list 1]
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 14} {
        ui::show -name "A13_txt"
        ui::show -name "GROUP_A13"
        ui::show -name "PAD_A13"
        ui::setValue -name "A13_EN" -value 1
        set i 1
    } else {
        ui::hide -name "A13_txt"
        ui::hide -name "GROUP_A13"
        ui::hide -name "PAD_A13"
        ui::setValue -name "A13_EN" -value 0
        set i 0
    }
    set all_pad_list [lreplace $all_pad_list 25 25 [list "A13" $j $i]]
}

proc upd_show_a14 {} {
    global all_pad_list
    set update_list [lindex $all_pad_list 26]
    set j [lindex $update_list 1]
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 15} {
        ui::show -name "A14_txt"
        ui::setText -name "A14_txt" -text "A14"
        ui::show -name "GROUP_A14"
        ui::show -name "PAD_A14"
        ui::setValue -name "A14_EN" -value 1
        set i 1
    } else {
        ui::hide -name "A14_txt"
        ui::hide -name "GROUP_A14"
        ui::hide -name "PAD_A14"
        ui::setValue -name "A14_EN" -value 0
        set i 0
    }
    set all_pad_list [lreplace $all_pad_list 26 26 [list "A14" $j $i]]
}

proc upd_show_a15 {} {
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 16} {
        ui::show -name "A15_txt"
        ui::setText -name "A15_txt" -text "A15"
        ui::show -name "GROUP_A15"
        ui::show -name "PAD_A15"
        ui::setValue -name "A15_EN" -value 1
    } else {
        ui::hide -name "A15_txt"
        ui::hide -name "GROUP_A15"
        ui::hide -name "PAD_A15"
        ui::setValue -name "A15_EN" -value 0
    }
}

proc upd_pin_group {pin_group pin_name} {
    ui::setItems -name $pin_name -items {*}[ui::getPkgPins -bank [ui::getValue -name "BANK_CA"] -group $pin_group]
}

proc upd_pin_rst {} {
    ui::setItems -name "PAD_RESET" -items {*}[ui::getPkgPins -bank [ui::getValue -name "BANK_CA"]]
}

proc upd_pin_cke      {} { upd_pin_group [ui::getValue -name "GROUP_CKE"      ] "PAD_CKE"      }
proc upd_pin_ck       {} { upd_pin_group [ui::getValue -name "GROUP_CK"       ] "PAD_CK"       }
proc upd_pin_ckn      {} { upd_pin_group [ui::getValue -name "GROUP_CKN"      ] "PAD_CKN"      }
proc upd_pin_cs       {} { upd_pin_group [ui::getValue -name "GROUP_CS"       ] "PAD_CS"       }
proc upd_pin_ras      {} { upd_pin_group [ui::getValue -name "GROUP_RAS"      ] "PAD_RAS"      }
proc upd_pin_cas      {} { upd_pin_group [ui::getValue -name "GROUP_CAS"      ] "PAD_CAS"      }
proc upd_pin_we       {} { upd_pin_group [ui::getValue -name "GROUP_WE"       ] "PAD_WE"       }
proc upd_pin_odt      {} { upd_pin_group [ui::getValue -name "GROUP_ODT"      ] "PAD_ODT"      }
proc upd_pin_ba0      {} { upd_pin_group [ui::getValue -name "GROUP_BA0"      ] "PAD_BA0"      }
proc upd_pin_ba1      {} { upd_pin_group [ui::getValue -name "GROUP_BA1"      ] "PAD_BA1"      }
proc upd_pin_ba2      {} { upd_pin_group [ui::getValue -name "GROUP_BA2"      ] "PAD_BA2"      }
proc upd_pin_a0       {} { upd_pin_group [ui::getValue -name "GROUP_A0"       ] "PAD_A0"       }
proc upd_pin_a1       {} { upd_pin_group [ui::getValue -name "GROUP_A1"       ] "PAD_A1"       }
proc upd_pin_a2       {} { upd_pin_group [ui::getValue -name "GROUP_A2"       ] "PAD_A2"       }
proc upd_pin_a3       {} { upd_pin_group [ui::getValue -name "GROUP_A3"       ] "PAD_A3"       }
proc upd_pin_a4       {} { upd_pin_group [ui::getValue -name "GROUP_A4"       ] "PAD_A4"       }
proc upd_pin_a5       {} { upd_pin_group [ui::getValue -name "GROUP_A5"       ] "PAD_A5"       }
proc upd_pin_a6       {} { upd_pin_group [ui::getValue -name "GROUP_A6"       ] "PAD_A6"       }
proc upd_pin_a7       {} { upd_pin_group [ui::getValue -name "GROUP_A7"       ] "PAD_A7"       }
proc upd_pin_a8       {} { upd_pin_group [ui::getValue -name "GROUP_A8"       ] "PAD_A8"       }
proc upd_pin_a9       {} { upd_pin_group [ui::getValue -name "GROUP_A9"       ] "PAD_A9"       }
proc upd_pin_a10      {} { upd_pin_group [ui::getValue -name "GROUP_A10"      ] "PAD_A10"      }
proc upd_pin_a11      {} { upd_pin_group [ui::getValue -name "GROUP_A11"      ] "PAD_A11"      }
proc upd_pin_a12      {} { upd_pin_group [ui::getValue -name "GROUP_A12"      ] "PAD_A12"      }
proc upd_pin_a13      {} { upd_pin_group [ui::getValue -name "GROUP_A13"      ] "PAD_A13"      }
proc upd_pin_a14      {} { upd_pin_group [ui::getValue -name "GROUP_A14"      ] "PAD_A14"      }
proc upd_pin_a15      {} { upd_pin_group [ui::getValue -name "GROUP_A15"      ] "PAD_A15"      }

proc upd_pin_ca {} {
    upd_pin_rst
    upd_pin_cke
    upd_pin_ck
    upd_pin_ckn
    upd_pin_cs
    upd_pin_ras
    upd_pin_cas
    upd_pin_we
    upd_pin_odt
    upd_pin_ba0
    upd_pin_ba1
    upd_pin_ba2
    upd_pin_a0
    upd_pin_a1
    upd_pin_a2
    upd_pin_a3
    upd_pin_a4
    upd_pin_a5
    upd_pin_a6
    upd_pin_a7
    upd_pin_a8
    upd_pin_a9
    upd_pin_a10
    upd_pin_a11
    upd_pin_a12
    upd_pin_a13
    upd_pin_a14
    upd_pin_a15

}

proc reassign_pin_ca {} {
    ui::setValue -name "PAD_RESET" -value [ui::getValue -name "PAD_RESET"]
    ui::setValue -name "PAD_CKE" -value [ui::getValue -name "PAD_CKE"]
    ui::setValue -name "PAD_CK" -value [ui::getValue -name "PAD_CK"]
    ui::setValue -name "PAD_CKN" -value [ui::getValue -name "PAD_CKN"]
    ui::setValue -name "PAD_CS" -value [ui::getValue -name "PAD_CS"]
    ui::setValue -name "PAD_RAS" -value [ui::getValue -name "PAD_RAS"]
    ui::setValue -name "PAD_CAS" -value [ui::getValue -name "PAD_CAS"]
    ui::setValue -name "PAD_WE" -value [ui::getValue -name "PAD_WE"]
    ui::setValue -name "PAD_ODT" -value [ui::getValue -name "PAD_ODT"]
    ui::setValue -name "PAD_BA0" -value [ui::getValue -name "PAD_BA0"]
    ui::setValue -name "PAD_BA1" -value [ui::getValue -name "PAD_BA1"]
    ui::setValue -name "PAD_BA2" -value [ui::getValue -name "PAD_BA2"]
    ui::setValue -name "PAD_A0" -value [ui::getValue -name "PAD_A0"]
    ui::setValue -name "PAD_A1" -value [ui::getValue -name "PAD_A1"]
    ui::setValue -name "PAD_A2" -value [ui::getValue -name "PAD_A2"]
    ui::setValue -name "PAD_A3" -value [ui::getValue -name "PAD_A3"]
    ui::setValue -name "PAD_A4" -value [ui::getValue -name "PAD_A4"]
    ui::setValue -name "PAD_A5" -value [ui::getValue -name "PAD_A5"]
    ui::setValue -name "PAD_A6" -value [ui::getValue -name "PAD_A6"]
    ui::setValue -name "PAD_A7" -value [ui::getValue -name "PAD_A7"]
    ui::setValue -name "PAD_A8" -value [ui::getValue -name "PAD_A8"]
    ui::setValue -name "PAD_A9" -value [ui::getValue -name "PAD_A9"]
    ui::setValue -name "PAD_A10" -value [ui::getValue -name "PAD_A10"]
    ui::setValue -name "PAD_A11" -value [ui::getValue -name "PAD_A11"]
    ui::setValue -name "PAD_A12" -value [ui::getValue -name "PAD_A12"]
    ui::setValue -name "PAD_A13" -value [ui::getValue -name "PAD_A13"]
    ui::setValue -name "PAD_A14" -value [ui::getValue -name "PAD_A14"]
    ui::setValue -name "PAD_A15" -value [ui::getValue -name "PAD_A15"]
}

proc reassign_bank_group_ca_dq {} {
    set bank_ca_dq_list [list "BANK_CA" "BANK_DQG_0" "BANK_DQG_1" "BANK_DQG_2" "BANK_DQG_3"]
    set group_ca_dq_list [list CKE ODT CK CKN CS BA0 BA1 BA2 A0 A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13 A14 A15 RAS CAS WE \
                          DQG_0 DQG_1 DQG_2 DQG_3]
                         
    foreach bank_ca_dq $bank_ca_dq_list {
        ui::setValue -name $bank_ca_dq -value [ui::getValue -name $bank_ca_dq]
    }

    foreach group_ca_dq $group_ca_dq_list {
        ui::setValue -name "GROUP_$group_ca_dq" -value [ui::getValue -name "GROUP_$group_ca_dq"]
    }
}

proc upd_show_dq {} {
    upd_show_dq_g0
    upd_show_dq_g1
    upd_show_dq_g2
    upd_show_dq_g3
}

proc upd_show_dq_g0 {} {
    ui::setItems -n "BANK_DQG_0" -items "[ui::getValue -name "BANK_CA"]"
    ui::show -name "GROUP_DQG_0"
    ui::setValue -name "DQ0_EN" -value 1
}

proc upd_show_dq_g1 {} {
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 8} {
        ui::show -name "dq_txt1"
        ui::show -name "BANK_DQG_1"
        ui::show -name "GROUP_DQG_1"
        ui::show -name dq1_txt
        ui::show -name "DQ1_txt"
        ui::show -name dq1_group_txt
        ui::show -name "DQ1_group_txt"
        ui::setItems -n "BANK_DQG_1" -items "[ui::getValue -name "BANK_CA"]"
        ui::setValue -name "DQ1_EN" -value 1
    } else {
        ui::hide -name "dq_txt1"
        ui::hide -name "BANK_DQG_1"
        ui::hide -name "GROUP_DQG_1"
        ui::hide -name dq1_txt
        ui::hide -name "DQ1_txt"
        ui::hide -name dq1_group_txt
        ui::hide -name "DQ1_group_txt"
        ui::setValue -name "DQ1_EN" -value 0
    }
}

proc upd_show_dq_g2 {} {
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 16} {
        ui::show -name "dq_txt2"
        ui::show -name "BANK_DQG_2"
        ui::show -name "GROUP_DQG_2"
        ui::show -name dq2_txt
        ui::show -name "DQ2_txt"
        ui::show -name dq2_group_txt
        ui::show -name "DQ2_group_txt"
        ui::setItems -n "BANK_DQG_2" -items "[ui::getValue -name "BANK_CA"]"
        ui::setValue -name "DQ2_EN" -value 1
    } else {
        ui::hide -name "dq_txt2"
        ui::hide -name "BANK_DQG_2"
        ui::hide -name "GROUP_DQG_2"
        ui::hide -name dq2_txt
        ui::hide -name "DQ2_txt"
        ui::hide -name dq2_group_txt
        ui::hide -name "DQ2_group_txt"
        ui::setValue -name "DQ2_EN" -value 0
    }
}

proc upd_show_dq_g3 {} {
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 24} {
        ui::show -name "dq_txt3"
        ui::show -name "BANK_DQG_3"
        ui::show -name "GROUP_DQG_3"
        ui::show -name dq3_txt
        ui::show -name "DQ3_txt"
        ui::show -name dq3_group_txt
        ui::show -name "DQ3_group_txt"
        ui::setItems -n "BANK_DQG_3" -items "[ui::getValue -name "BANK_CA"]"
        ui::setValue -name "DQ3_EN" -value 1
    } else {
        ui::hide -name "dq_txt3"
        ui::hide -name "BANK_DQG_3"
        ui::hide -name "GROUP_DQG_3"
        ui::hide -name dq3_txt
        ui::hide -name "DQ3_txt"
        ui::hide -name dq3_group_txt
        ui::hide -name "DQ3_group_txt"
        ui::setValue -name "DQ3_EN" -value 0
    }
}


proc upd_dq_group_pkg {} {
    set dq_group_pkg_list [list "DQG_0" "DQG_1" "DQG_2" "DQG_3"]

    foreach dq_group_pkg $dq_group_pkg_list {
        if {[ui::getDevice] == "PGL25G"} {
            ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5"
        } elseif {[ui::getDevice] == "PGL50H"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                if {[ui::getPackage] == "MBG324"} {
                    ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G2" "G3" "G4" "G5" "G6"
                } else {
                    ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7"
                }
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                if {[ui::getPackage] == "MBG324"} {
                    ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G2" "G3" "G4" "G5" "G8"
                } else {
                    ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8"
                }
            }
        } elseif {[ui::getDevice] == "PGL50G"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                if {[ui::getPackage] == "MBG324"} {
                    ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G2" "G3" "G4" "G5" "G6"
                } else {
                    ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7"
                }
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                if {[ui::getPackage] == "MBG324"} {
                    ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G2" "G3" "G4" "G5" "G8"
                } else {
                    ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8"
                }
            }
        } elseif {[ui::getDevice] == "PGL100H"} {
            if {[ui::getValue -name "BANK_CA"] == "B1"} {
                ui::setItems -n "GROUP_$dq_group_pkg" -items "G1" "G2" "G3" "G4" "G5" "G6" "G7"
            } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                ui::setItems -n "GROUP_$dq_group_pkg" -items "G0" "G1" "G2" "G3" "G4" "G5" "G6" "G7" "G8"
            }
        }
    }
}

proc upd_dq_bank_group_recfg {} {
    global dq_bank_group_recfg
    set dq_bank_group_recfg 1
}

proc upd_dq_bank_group_init {} {
    global dq_bank_group_recfg
    set dq_bank_group_recfg 0
}

# step4: summary
proc upd_summary_mem_type {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::setText -name "Memory_Type_txt" -text ": DDR3"
    }
}

proc upd_summary_operate_mode {} {
    if {[ui::getValue -name "OPERATING_MODE"] == "Controller + PHY"} {
        ui::setText -name "Operating_Mode_txt" -text ": Controller + PHY"
    }
}

proc upd_summary_data_width {} {
    ui::setText -name "Total_Data_Width_txt" -text ": [ui::getValue -name "MEM_DQ_WIDTH"]"
}

proc upd_summary_density {} {
    set mem_part [ui::getValue -name "DDR_MEM_PART"]
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        switch -exact $mem_part {
            "MT41J128M8xx-15E" -
            "MT41J64M16xx-15E" {
                ui::setText -name "Density_txt"  -text ": 1Gb"
            }
            "MT41J128M16xx-15E" -
            "MT41J256M8xx-15E" {
                ui::setText -name "Density_txt"  -text ": 2Gb"
            }
            "MT41K256M16xx-15E"  {
                ui::setText -name "Density_txt"  -text ": 4Gb"
            }
        }
    }
}

proc upd_summary_volt {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::setText -name "Volt_txt" -text ": 1.5V"
    }
}

proc upd_summary_refclk_frequency {} {
    ui::setText -name "Input_Clock_txt" -text ": [ui::getValue -name "CLKIN_FREQ"]MHz"
}

proc upd_summary_data_rate {} {
    ui::setText -name "Data_Rate_txt" -text ": [ui::getValue -name "ACTUAL_RATE"]Mbps"
}

proc upd_summary_debug_enable {} {
    if {[ui::getValue -name "Debug_Signals_En"]} {
        ui::setText -name "Debug_Signals_txt" -t ": Enabled"
    } else {
        ui::setText -name "Debug_Signals_txt" -t ": Disabled"
    }
}

proc upd_summary_basic {} {
    upd_summary_mem_type
    upd_summary_operate_mode
    upd_summary_data_width
    upd_summary_density
    upd_summary_volt
    upd_summary_refclk_frequency
    upd_summary_data_rate
    upd_summary_debug_enable
}

proc upd_summary_memory_part {} {
    ui::setText -name "Memory_Part_txt" -text ": [ui::getValue -name "DDR_MEM_PART"]"
}

proc upd_summary_addr {} {
    ui::setText -name "Row_Address_txt" -text ": [ui::getValue -name "MEM_ROW_WIDTH"]"
    ui::setText -name "Column_Address_txt" -text ": [ui::getValue -name "MEM_COLUMN_WIDTH"]"
    ui::setText -name "Bank_Address_txt" -text ": [ui::getValue -name "MEM_BANK_WIDTH"]"
}

proc upd_summary_odi {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "DDR3_Output_Driver"
        ui::show -name "DDR3_Output_Driver_txt"

        if {[ui::getValue -name "DDR3_OUTPUT_DRIVER"] == 00} {
            ui::setText -name "DDR3_Output_Driver_txt" -text ": RZQ/6"
        } elseif {[ui::getValue -name "DDR3_OUTPUT_DRIVER"] == 01} {
            ui::setText -name "DDR3_Output_Driver_txt" -text ": RZQ/7"
        }
    }
}

proc upd_summary_odt {} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::show -name "DDR3_RTT_ODT"
        ui::show -name "DDR3_RTT_ODT_txt"

        if {[ui::getValue -name "DDR3_ODT_VALUE"] == 001} {
            ui::setText -name "DDR3_RTT_ODT_txt" -text ": RZQ/4"
        } elseif {[ui::getValue -name "DDR3_ODT_VALUE"] == 010} {
            ui::setText -name "DDR3_RTT_ODT_txt" -text ": RZQ/2"
        } elseif {[ui::getValue -name "DDR3_ODT_VALUE"] == 011} {
            ui::setText -name "DDR3_RTT_ODT_txt" -text ": RZQ/6"
        }
    }
}

proc upd_summary_memory_option {} {
    upd_summary_memory_part
    upd_summary_addr
    upd_summary_odi
    upd_summary_odt
}

proc upd_summary_ca_bank {} {
    ui::setText -name "CA_txt" -text ": [ui::getValue -name "BANK_CA"]"
}

proc upd_show_dq_txt {} {
    upd_show_dq_txt_g0
    upd_show_dq_txt_g1
    upd_show_dq_txt_g2
    upd_show_dq_txt_g3
}

proc upd_show_dq_txt_g0 {} {
    ui::setText -name "DQ0_txt" -text ": [ui::getValue -name "BANK_DQG_0"]"
    ui::setText -name "DQ0_group_txt" -text ": [ui::getValue -name "GROUP_DQG_0"]"
    ui::setValue -name "DQ0_EN" -value 1
}

proc upd_show_dq_txt_g1 {} {
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 8} {
        ui::show -name "dq_txt1"
        ui::show -name "BANK_DQG_1"
        ui::show -name dq1_txt
        ui::show -name "DQ1_txt"
        ui::setText -name "DQ1_txt" -text ": [ui::getValue -name "BANK_DQG_1"]"
        ui::show -name dq1_group_txt
        ui::show -name "DQ1_group_txt"
        ui::setText -name "DQ1_group_txt" -text ": [ui::getValue -name "GROUP_DQG_1"]"
        ui::setValue -name "DQ1_EN" -value 1
    } else {
        ui::hide -name "dq_txt1"
        ui::hide -name "BANK_DQG_1"
        ui::hide -name dq1_txt
        ui::hide -name "DQ1_txt"
        ui::hide -name dq1_group_txt
        ui::hide -name "DQ1_group_txt"
        ui::setValue -name "DQ1_EN" -value 0
    }
}

proc upd_show_dq_txt_g2 {} {
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 16} {
        ui::show -name "dq_txt2"
        ui::show -name "BANK_DQG_2"
        ui::show -name dq2_txt
        ui::show -name "DQ2_txt"
        ui::setText -name "DQ2_txt" -text ": [ui::getValue -name "BANK_DQG_2"]"
        ui::show -name dq2_group_txt
        ui::show -name "DQ2_group_txt"
        ui::setText -name "DQ2_group_txt" -text ": [ui::getValue -name "GROUP_DQG_2"]"
        ui::setValue -name "DQ2_EN" -value 1
    } else {
        ui::hide -name "dq_txt2"
        ui::hide -name "BANK_DQG_2"
        ui::hide -name dq2_txt
        ui::hide -name "DQ2_txt"
        ui::hide -name dq2_group_txt
        ui::hide -name "DQ2_group_txt"
        ui::setValue -name "DQ2_EN" -value 0
    }
}

proc upd_show_dq_txt_g3 {} {
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 24} {
        ui::show -name "dq_txt3"
        ui::show -name "BANK_DQG_3"
        ui::show -name dq3_txt
        ui::show -name "DQ3_txt"
        ui::setText -name "DQ3_txt" -text ": [ui::getValue -name "BANK_DQG_3"]"
        ui::show -name dq3_group_txt
        ui::show -name "DQ3_group_txt"
        ui::setText -name "DQ3_group_txt" -text ": [ui::getValue -name "GROUP_DQG_3"]"
        ui::setValue -name "DQ3_EN" -value 1
    } else {
        ui::hide -name "dq_txt3"
        ui::hide -name "BANK_DQG_3"
        ui::hide -name dq3_txt
        ui::hide -name "DQ3_txt"
        ui::hide -name dq3_group_txt
        ui::hide -name "DQ3_group_txt"
        ui::setValue -name "DQ3_EN" -value 0
    }
}


########################################################################################
################################# symbol update proc ###################################
########################################################################################

proc upd_symbol_pins_show {} {
    upd_symbol_pin_show "CS_n_EN"
}

proc upd_symbol_pin_show {show_en} {

    global pin_show_CS_n_EN

    set pin_show_list "pin_show_${show_en}"
    foreach symbol_pin [set $pin_show_list] {
        if {[ui::getValue -name $show_en] == 0} {
            ui::hide -pin -name $symbol_pin
        } else {
            ui::show -pin -name $symbol_pin
        }
    }
}

proc upd_symbol_pins_width {} {

    upd_symbol_pin_width_a "MEM_BANK_WIDTH"
    upd_symbol_pin_width_a "MEM_DQS_WIDTH"
    upd_symbol_pin_width_a "MEM_DQ_WIDTH"
    upd_symbol_pin_width_a "MEM_DM_WIDTH"
    upd_symbol_pin_width_a "CTRL_ADDR_WIDTH"
    upd_symbol_pin_width_a "MEM_ROW_WIDTH"

    upd_symbol_pin_width_b "MEM_DQS_WIDTH"
    upd_symbol_pin_width_b "MEM_DQ_WIDTH"

}

proc upd_symbol_pin_width_a {width_par} {

    global pin_show_a_MEM_BANK_WIDTH
    global pin_show_a_MEM_DQS_WIDTH
    global pin_show_a_MEM_DM_WIDTH
    global pin_show_a_MEM_DQ_WIDTH
    global pin_show_a_CTRL_ADDR_WIDTH
    global pin_show_a_MEM_ROW_WIDTH

    set pin_show_a_list "pin_show_a_${width_par}"
    foreach symbol_pin_width [set $pin_show_a_list] {
        ui::setPinIndex -name $symbol_pin_width -msb [expr [ui::getValue -name $width_par] - 1]
    }
}

proc upd_symbol_pin_width_b {width_par} {

    global pin_show_b_MEM_ADDR_WIDTH
    global pin_show_b_MEM_DQS_WIDTH
    global pin_show_b_MEM_DQ_WIDTH

    global fix_pin_show_b_MEM_ADDR_WIDTH
    global fix_pin_show_b_MEM_DQS_WIDTH
    global fix_pin_show_b_MEM_DQ_WIDTH

    set idx_b 0
    set pin_show_b_list "pin_show_b_${width_par}"
    set fix_pin_show_b_list "fix_pin_show_b_${width_par}"
    foreach symbol_pin_width [set $pin_show_b_list] {
        set pin_fix_width [lindex [set $fix_pin_show_b_list] $idx_b]
        ui::setPinIndex -name $symbol_pin_width -msb [expr [ui::getValue -name $width_par] * $pin_fix_width - 1]
        incr idx_b
    }
}

########################################################################################
################################### ui check proc ######################################
######################################################################################## 

proc check_dq_group_number {} {
    ui::setValue -name "GROUP_DQG_0_NUM" -value 9
    ui::setValue -name "GROUP_DQG_1_NUM" -value 9
    ui::setValue -name "GROUP_DQG_2_NUM" -value 9
    ui::setValue -name "GROUP_DQG_3_NUM" -value 9

    get_dq_group_number "DQ0_EN" "GROUP_DQG_0" "GROUP_DQG_0_NUM"
    get_dq_group_number "DQ1_EN" "GROUP_DQG_1" "GROUP_DQG_1_NUM"
    get_dq_group_number "DQ2_EN" "GROUP_DQG_2" "GROUP_DQG_2_NUM"
    get_dq_group_number "DQ3_EN" "GROUP_DQG_3" "GROUP_DQG_3_NUM"

}

proc get_dq_group_number {dq_group_en dq_group dq_group_number} {
    if {[ui::getValue -name $dq_group_en]} {
        switch -exact [ui::getValue -name $dq_group] {
            "G0" { ui::setValue -name $dq_group_number -value 0 }
            "G1" { ui::setValue -name $dq_group_number -value 1 }
            "G2" { ui::setValue -name $dq_group_number -value 2 }
            "G3" { ui::setValue -name $dq_group_number -value 3 }
            "G4" { ui::setValue -name $dq_group_number -value 4 }
            "G5" { ui::setValue -name $dq_group_number -value 5 }
            "G6" { ui::setValue -name $dq_group_number -value 6 }
            "G7" { ui::setValue -name $dq_group_number -value 7 }
            "G8" { ui::setValue -name $dq_group_number -value 8 }
        }
    }
}

proc check_region_number {} {
    get_region_number "A0_GROUP_NUM" "A0_REG_NUM"
    get_region_number "A1_GROUP_NUM" "A1_REG_NUM"
    get_region_number "A2_GROUP_NUM" "A2_REG_NUM"
    get_region_number "A3_GROUP_NUM" "A3_REG_NUM"
    get_region_number "A4_GROUP_NUM" "A4_REG_NUM"
    get_region_number "A5_GROUP_NUM" "A5_REG_NUM"
    get_region_number "A6_GROUP_NUM" "A6_REG_NUM"
    get_region_number "A7_GROUP_NUM" "A7_REG_NUM"
    get_region_number "A8_GROUP_NUM" "A8_REG_NUM"
    get_region_number "A9_GROUP_NUM" "A9_REG_NUM"
    get_region_number "A10_GROUP_NUM" "A10_REG_NUM"
    get_region_number "A11_GROUP_NUM" "A11_REG_NUM"

    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 13} {
        get_region_number "A12_GROUP_NUM" "A12_REG_NUM"
    }
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 14} {
        get_region_number "A13_GROUP_NUM" "A13_REG_NUM"
    }
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 15} {
        get_region_number "A14_GROUP_NUM" "A14_REG_NUM"
    }
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 16} {
        get_region_number "A15_GROUP_NUM" "A15_REG_NUM"
    }

    get_region_number "CKE_GROUP_NUM" "CKE_REG_NUM"
    get_region_number "CK_GROUP_NUM" "CK_REG_NUM"
    if {[ui::getValue -name "CS_n_EN"]} {
        get_region_number "CS_GROUP_NUM" "CS_REG_NUM"
    }
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        get_region_number "RAS_GROUP_NUM" "RAS_REG_NUM"
        get_region_number "CAS_GROUP_NUM" "CAS_REG_NUM"
        get_region_number "WE_GROUP_NUM" "WE_REG_NUM"
        get_region_number "BA2_GROUP_NUM" "BA2_REG_NUM"
    }
    get_region_number "ODT_GROUP_NUM" "ODT_REG_NUM"
    get_region_number "BA0_GROUP_NUM" "BA0_REG_NUM"
    get_region_number "BA1_GROUP_NUM" "BA1_REG_NUM"

    if {[ui::getValue -name "DQ0_EN"]} {
        get_region_number "GROUP_DQG_0_NUM" "DQG_0_REG_NUM"
    }
    if {[ui::getValue -name "DQ1_EN"]} {
        get_region_number "GROUP_DQG_1_NUM" "DQG_1_REG_NUM"
    }
    if {[ui::getValue -name "DQ2_EN"]} {
        get_region_number "GROUP_DQG_2_NUM" "DQG_2_REG_NUM"
    }
    if {[ui::getValue -name "DQ3_EN"]} {
        get_region_number "GROUP_DQG_3_NUM" "DQG_3_REG_NUM"
    }
}

proc get_region_number {pin_group_number pin_region_num} {
    switch -exact [ui::getValue -name $pin_group_number] {
        0 { ui::setValue -name $pin_region_num -value 0 }
        1 { ui::setValue -name $pin_region_num -value 0 }
        2 { ui::setValue -name $pin_region_num -value 0 }
        3 { ui::setValue -name $pin_region_num -value 1 }
        4 { ui::setValue -name $pin_region_num -value 1 }
        5 { ui::setValue -name $pin_region_num -value 1 }
        6 { ui::setValue -name $pin_region_num -value 2 }
        7 { ui::setValue -name $pin_region_num -value 2 }
        8 { ui::setValue -name $pin_region_num -value 2 }
    }
}

proc check_ca_group_used {} {
    global ca_g0_used
    global ca_g1_used
    global ca_g2_used
    global ca_g3_used
    global ca_g4_used
    global ca_g5_used
    global ca_g6_used
    global ca_g7_used
    global ca_g8_used
    global ca_group_num

    set ca_g0_used 0
    set ca_g1_used 0
    set ca_g2_used 0
    set ca_g3_used 0
    set ca_g4_used 0
    set ca_g5_used 0
    set ca_g6_used 0
    set ca_g7_used 0
    set ca_g8_used 0
    set ca_group_num 0

    check_fix_ca_group_used
    check_var_ca_group_used
}

proc check_fix_ca_group_used {} {
    set fix_ca_list [list "CKE" "ODT" "CK" "BA0" "BA1" "A0" "A1" "A2" "A3" "A4" "A5" "A6" "A7" "A8" "A9" "A10" "A11"]

    foreach fix_ca $fix_ca_list {
        check_ca_pin_group_used "GROUP_${fix_ca}" "${fix_ca}_GROUP_NUM" 
        check_ca_pin_group "GROUP_${fix_ca}" "CA_GROUP_${fix_ca}"
    }
}

proc check_var_ca_group_used {} {

    if {[ui::getValue -name "CS_n_EN"]} {
        check_ca_pin_group_used "GROUP_CS" "CS_GROUP_NUM"
        check_ca_pin_group "GROUP_CS" "CA_GROUP_CS"
    }
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        check_ca_pin_group_used "GROUP_RAS" "RAS_GROUP_NUM"
        check_ca_pin_group_used "GROUP_CAS" "CAS_GROUP_NUM"
        check_ca_pin_group_used "GROUP_WE" "WE_GROUP_NUM"
        check_ca_pin_group_used "GROUP_BA2" "BA2_GROUP_NUM"
        check_ca_pin_group "GROUP_RAS" "CA_GROUP_RAS"
        check_ca_pin_group "GROUP_CAS" "CA_GROUP_CAS"
        check_ca_pin_group "GROUP_WE" "CA_GROUP_WE"
        check_ca_pin_group "GROUP_BA2" "CA_GROUP_BA2"
    }
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 13} {
        check_ca_pin_group_used "GROUP_A12" "A12_GROUP_NUM"
        check_ca_pin_group "GROUP_A12" "CA_GROUP_A12"
    }
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 14} {
        check_ca_pin_group_used "GROUP_A13" "A13_GROUP_NUM"
        check_ca_pin_group "GROUP_A13" "CA_GROUP_A13"
    }
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 15} {
        check_ca_pin_group_used "GROUP_A14" "A14_GROUP_NUM"
        check_ca_pin_group "GROUP_A14" "CA_GROUP_A14"
    }
    if {[ui::getValue -name "MEM_ADDR_WIDTH"] >= 16} {
        check_ca_pin_group_used "GROUP_A15" "A15_GROUP_NUM"
        check_ca_pin_group "GROUP_A15" "CA_GROUP_A15"
    }
}

proc check_ca_pin_group {ca_pin_group ca_pin_group_number} {
    if {[ui::getValue -name $ca_pin_group] == [ui::getValue -name "CA_GROUP0"]} {
        ui::setValue -name $ca_pin_group_number -value 0
    } elseif {[ui::getValue -name $ca_pin_group] == [ui::getValue -name "CA_GROUP1"]} {
        ui::setValue -name $ca_pin_group_number -value 1
    } elseif {[ui::getValue -name $ca_pin_group] == [ui::getValue -name "CA_GROUP2"]} {
        ui::setValue -name $ca_pin_group_number -value 2
    } elseif {[ui::getValue -name $ca_pin_group] == [ui::getValue -name "CA_GROUP3"]} {
        ui::setValue -name $ca_pin_group_number -value 3
    } elseif {[ui::getValue -name $ca_pin_group] == [ui::getValue -name "CA_GROUP4"]} {
        ui::setValue -name $ca_pin_group_number -value 4
    }

}

proc check_ca_pin_group_region {} {
    if {[ui::getValue -name "CA_GROUP0"] == "G0"} {
        ui::setValue -name "CA_GROUP0_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP0"] == "G1"} {
        ui::setValue -name "CA_GROUP0_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP0"] == "G2"} {
        ui::setValue -name "CA_GROUP0_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP0"] == "G3"} {
        ui::setValue -name "CA_GROUP0_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP0"] == "G4"} {
        ui::setValue -name "CA_GROUP0_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP0"] == "G5"} {
        ui::setValue -name "CA_GROUP0_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP0"] == "G6"} {
        ui::setValue -name "CA_GROUP0_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP0"] == "G7"} {
        ui::setValue -name "CA_GROUP0_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP0"] == "G8"} {
        ui::setValue -name "CA_GROUP0_REG" -value 2
    }

    if {[ui::getValue -name "CA_GROUP1"] == "G0"} {
        ui::setValue -name "CA_GROUP1_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP1"] == "G1"} {
        ui::setValue -name "CA_GROUP1_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP1"] == "G2"} {
        ui::setValue -name "CA_GROUP1_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP1"] == "G3"} {
        ui::setValue -name "CA_GROUP1_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP1"] == "G4"} {
        ui::setValue -name "CA_GROUP1_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP1"] == "G5"} {
        ui::setValue -name "CA_GROUP1_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP1"] == "G6"} {
        ui::setValue -name "CA_GROUP1_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP1"] == "G7"} {
        ui::setValue -name "CA_GROUP1_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP1"] == "G8"} {
        ui::setValue -name "CA_GROUP1_REG" -value 2
    }

    if {[ui::getValue -name "CA_GROUP2"] == "G0"} {
        ui::setValue -name "CA_GROUP2_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP2"] == "G1"} {
        ui::setValue -name "CA_GROUP2_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP2"] == "G2"} {
        ui::setValue -name "CA_GROUP2_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP2"] == "G3"} {
        ui::setValue -name "CA_GROUP2_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP2"] == "G4"} {
        ui::setValue -name "CA_GROUP2_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP2"] == "G5"} {
        ui::setValue -name "CA_GROUP2_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP2"] == "G6"} {
        ui::setValue -name "CA_GROUP2_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP2"] == "G7"} {
        ui::setValue -name "CA_GROUP2_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP2"] == "G8"} {
        ui::setValue -name "CA_GROUP2_REG" -value 2
    }

    if {[ui::getValue -name "CA_GROUP3"] == "G0"} {
        ui::setValue -name "CA_GROUP3_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP3"] == "G1"} {
        ui::setValue -name "CA_GROUP3_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP3"] == "G2"} {
        ui::setValue -name "CA_GROUP3_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP3"] == "G3"} {
        ui::setValue -name "CA_GROUP3_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP3"] == "G4"} {
        ui::setValue -name "CA_GROUP3_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP3"] == "G5"} {
        ui::setValue -name "CA_GROUP3_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP3"] == "G6"} {
        ui::setValue -name "CA_GROUP3_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP3"] == "G7"} {
        ui::setValue -name "CA_GROUP3_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP3"] == "G8"} {
        ui::setValue -name "CA_GROUP3_REG" -value 2
    }

    if {[ui::getValue -name "CA_GROUP4"] == "G0"} {
        ui::setValue -name "CA_GROUP4_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP4"] == "G1"} {
        ui::setValue -name "CA_GROUP4_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP4"] == "G2"} {
        ui::setValue -name "CA_GROUP4_REG" -value 0
    } elseif {[ui::getValue -name "CA_GROUP4"] == "G3"} {
        ui::setValue -name "CA_GROUP4_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP4"] == "G4"} {
        ui::setValue -name "CA_GROUP4_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP4"] == "G5"} {
        ui::setValue -name "CA_GROUP4_REG" -value 1
    } elseif {[ui::getValue -name "CA_GROUP4"] == "G6"} {
        ui::setValue -name "CA_GROUP4_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP4"] == "G7"} {
        ui::setValue -name "CA_GROUP4_REG" -value 2
    } elseif {[ui::getValue -name "CA_GROUP4"] == "G8"} {
        ui::setValue -name "CA_GROUP4_REG" -value 2
    }

}

proc check_ca_pin_group_used {ca_signal_group ca_signal_group_num} {
    global ca_g0_used
    global ca_g1_used
    global ca_g2_used
    global ca_g3_used
    global ca_g4_used
    global ca_g5_used
    global ca_g6_used
    global ca_g7_used
    global ca_g8_used
    global ca_group_num

    switch -exact [ui::getValue -name $ca_signal_group] {
        "G0" { set ca_g0_used 1 }
        "G1" { set ca_g1_used 1 }
        "G2" { set ca_g2_used 1 }
        "G3" { set ca_g3_used 1 }
        "G4" { set ca_g4_used 1 }
        "G5" { set ca_g5_used 1 }
        "G6" { set ca_g6_used 1 }
        "G7" { set ca_g7_used 1 }
        "G8" { set ca_g8_used 1 }
    }

    set ca_group_num [expr $ca_g0_used+$ca_g1_used+$ca_g2_used+$ca_g3_used+$ca_g4_used+$ca_g5_used+$ca_g6_used+$ca_g7_used+$ca_g8_used]


    if {$ca_group_num == 1} {
        ui::setValue -name "CA_GROUP0" -value [ui::getValue -name $ca_signal_group]
    } elseif {($ca_group_num == 2) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP0"])} {
        ui::setValue -name "CA_GROUP1" -value [ui::getValue -name $ca_signal_group] 
    } elseif {($ca_group_num == 3) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP0"]) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP1"])} {
        ui::setValue -name "CA_GROUP2" -value [ui::getValue -name $ca_signal_group]
    } elseif {($ca_group_num == 4) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP0"]) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP1"]) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP2"])} {
        ui::setValue -name "CA_GROUP3" -value [ui::getValue -name $ca_signal_group]
    } elseif {($ca_group_num == 5) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP0"]) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP1"]) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP2"]) && ([ui::getValue -name $ca_signal_group] != [ui::getValue -name "CA_GROUP3"])} {
        ui::setValue -name "CA_GROUP4" -value [ui::getValue -name $ca_signal_group]
    }

    if {$ca_signal_group_num != ""} {
        switch -exact [ui::getValue -name $ca_signal_group] {
            "G0" { ui::setValue -name $ca_signal_group_num -value 0 }
            "G1" { ui::setValue -name $ca_signal_group_num -value 1 }
            "G2" { ui::setValue -name $ca_signal_group_num -value 2 }
            "G3" { ui::setValue -name $ca_signal_group_num -value 3 }
            "G4" { ui::setValue -name $ca_signal_group_num -value 4 }
            "G5" { ui::setValue -name $ca_signal_group_num -value 5 }
            "G6" { ui::setValue -name $ca_signal_group_num -value 6 }
            "G7" { ui::setValue -name $ca_signal_group_num -value 7 }
            "G8" { ui::setValue -name $ca_signal_group_num -value 8 }
        }
    }
}

proc check_ca_sig_group_num {} {
    global ca_g0_used
    global ca_g1_used
    global ca_g2_used
    global ca_g3_used
    global ca_g4_used
    global ca_g5_used
    global ca_g6_used
    global ca_g7_used
    global ca_g8_used

    ui::setValue -name "CA_GROUP_NUM" -value [expr $ca_g0_used+$ca_g1_used+$ca_g2_used+$ca_g3_used+$ca_g4_used+$ca_g5_used+$ca_g6_used+$ca_g7_used+$ca_g8_used]

    set ca_sig_group_num_list [list "CKE_GROUP_NUM" "CK_GROUP_NUM" "CS_GROUP_NUM" "RAS_GROUP_NUM" "CAS_GROUP_NUM" "WE_GROUP_NUM" "ODT_GROUP_NUM" "BA0_GROUP_NUM" "BA1_GROUP_NUM" "BA2_GROUP_NUM" "A0_GROUP_NUM" "A1_GROUP_NUM" "A2_GROUP_NUM" "A3_GROUP_NUM" "A4_GROUP_NUM" "A5_GROUP_NUM" "A6_GROUP_NUM" "A7_GROUP_NUM" "A8_GROUP_NUM" "A9_GROUP_NUM" "A10_GROUP_NUM" "A11_GROUP_NUM" "A12_GROUP_NUM" "A13_GROUP_NUM" "A14_GROUP_NUM" "A15_GROUP_NUM"]

    if {[expr $ca_g0_used+$ca_g1_used+$ca_g2_used+$ca_g3_used+$ca_g4_used+$ca_g5_used+$ca_g6_used+$ca_g7_used+$ca_g8_used] < 9} {
        if {$ca_g7_used == 0} {
            foreach ca_sig_group_num $ca_sig_group_num_list {
                if {[ui::getValue -name $ca_sig_group_num] > 7} {
                    ui::setValue -name $ca_sig_group_num -value [expr [ui::getValue -name $ca_sig_group_num]-1]
                }
            }
        }
        if {$ca_g6_used == 0} {
            foreach ca_sig_group_num $ca_sig_group_num_list {
                if {[ui::getValue -name $ca_sig_group_num] > 6} {
                    ui::setValue -name $ca_sig_group_num -value [expr [ui::getValue -name $ca_sig_group_num]-1]
                }
            }
        }
        if {$ca_g5_used == 0} {
            foreach ca_sig_group_num $ca_sig_group_num_list {
                if {[ui::getValue -name $ca_sig_group_num] > 5} {
                    ui::setValue -name $ca_sig_group_num -value [expr [ui::getValue -name $ca_sig_group_num]-1]
                }
            }
        }
        if {$ca_g4_used == 0} {
            foreach ca_sig_group_num $ca_sig_group_num_list {
                if {[ui::getValue -name $ca_sig_group_num] > 4} {
                    ui::setValue -name $ca_sig_group_num -value [expr [ui::getValue -name $ca_sig_group_num]-1]
                }
            }
        }
        if {$ca_g3_used == 0} {
            foreach ca_sig_group_num $ca_sig_group_num_list {
                if {[ui::getValue -name $ca_sig_group_num] > 3} {
                    ui::setValue -name $ca_sig_group_num -value [expr [ui::getValue -name $ca_sig_group_num]-1]
                }
            }
        }
        if {$ca_g2_used == 0} {
            foreach ca_sig_group_num $ca_sig_group_num_list {
                if {[ui::getValue -name $ca_sig_group_num] > 2} {
                    ui::setValue -name $ca_sig_group_num -value [expr [ui::getValue -name $ca_sig_group_num]-1]
                }
            }
        }
        if {$ca_g1_used == 0} {
            foreach ca_sig_group_num $ca_sig_group_num_list {
                if {[ui::getValue -name $ca_sig_group_num] > 1} {
                    ui::setValue -name $ca_sig_group_num -value [expr [ui::getValue -name $ca_sig_group_num]-1]
                }
            }
        }
        if {$ca_g0_used == 0} {
            foreach ca_sig_group_num $ca_sig_group_num_list {
                if {[ui::getValue -name $ca_sig_group_num] > 0} {
                    ui::setValue -name $ca_sig_group_num -value [expr [ui::getValue -name $ca_sig_group_num]-1]
                }
            }
        }
    }
}

proc check_ca_dq_region_used {} {
    global region_0_used
    global region_1_used
    global region_2_used

    set region_0_used 0
    set region_1_used 0
    set region_2_used 0

    check_region_used "GROUP_CKE"
    check_region_used "GROUP_CK"
    check_region_used "GROUP_CS"
    check_region_used "GROUP_RAS"
    check_region_used "GROUP_CAS"
    check_region_used "GROUP_WE"
    check_region_used "GROUP_ODT"
    check_region_used "GROUP_BA0"
    check_region_used "GROUP_BA1"
    check_region_used "GROUP_BA2"
    check_region_used "GROUP_A0"
    check_region_used "GROUP_A1"
    check_region_used "GROUP_A2"
    check_region_used "GROUP_A3"
    check_region_used "GROUP_A4"
    check_region_used "GROUP_A5"
    check_region_used "GROUP_A6"
    check_region_used "GROUP_A7"
    check_region_used "GROUP_A8"
    check_region_used "GROUP_A9"
    check_region_used "GROUP_A10"
    check_region_used "GROUP_A11"
    check_region_used "GROUP_A12"
    check_region_used "GROUP_A13"
    check_region_used "GROUP_A14"
    check_region_used "GROUP_A15"

    check_region_used "GROUP_DQG_0"
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 8} {
        check_region_used "GROUP_DQG_1"
    }
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 16} {
        check_region_used "GROUP_DQG_2"
    }
    if {[ui::getValue -name "MEM_DQ_WIDTH"] > 24} {
        check_region_used "GROUP_DQG_3"
    }

    ui::setValue -name "REGION_NUM" -value [expr $region_0_used+$region_1_used+$region_2_used]

}

proc check_region_used {signal_group_num} {
    global region_0_used
    global region_1_used
    global region_2_used
    
    switch -exact [ui::getValue -name $signal_group_num] {
        "G0" { set region_0_used 1 }
        "G1" { set region_0_used 1 }
        "G2" { set region_0_used 1 }
        "G3" { set region_1_used 1 }
        "G4" { set region_1_used 1 }
        "G5" { set region_1_used 1 }
        "G6" { set region_2_used 1 }
        "G7" { set region_2_used 1 }
        "G8" { set region_2_used 1 }

    }
}


proc check_mr_ddr3_wr {mem_clk_period_ns} {
    ui::setValue -name "DDR3_INIT_WR" -value [expr int(ceil(15.0/$mem_clk_period_ns))]

    switch -exact [ui::getValue -name "DDR3_INIT_WR"] {
        "5"  { ui::setValue -name "DDR3_WR" -value 1 }
        "6"  { ui::setValue -name "DDR3_WR" -value 2 }
        "7"  { ui::setValue -name "DDR3_WR" -value 3 }
        "8"  { ui::setValue -name "DDR3_WR" -value 4 }
        "10" { ui::setValue -name "DDR3_WR" -value 5 }
        "12" { ui::setValue -name "DDR3_WR" -value 6 }
        "14" { ui::setValue -name "DDR3_WR" -value 7 }
        "16" { ui::setValue -name "DDR3_WR" -value 0 }
    }
}

proc check_mr_ddr3_cl {} {
    switch -exact [ui::getValue -name "DDR3_CL"] {
        "5"  { ui::setValue -name "DDR3_CL_VALUE" -value 2 }
        "6"  { ui::setValue -name "DDR3_CL_VALUE" -value 4 }
    }
}

proc check_timing_para { dfi_clk_period mem_clk_period_ps} {
    if {[ui::getValue -name "MEM_TYPE"] == "DDR3"} {
        ui::setValue -name "tREFI" -value [expr int([ui::getValue -name "GUI_DDR3_TREFI"] * 1000)]
        ui::setValue -name "tRFC_MIN" -value [expr int([ui::getValue -name "GUI_DDR3_TRFC"]* 1000)]
        ui::setValue -name "PHY_TMRD" -value 4
        ui::setValue -name "PHY_TMOD" -value 12
        ui::setValue -name "PHY_TRCD" -value [expr int(ceil([ui::getValue -name "GUI_DDR3_TRCD"] * 1000 / double($dfi_clk_period)))]
        ui::setValue -name "PHY_TRP" -value [expr int(ceil([ui::getValue -name "GUI_DDR3_TRP"] * 1000 / double($dfi_clk_period)))]
        ui::setValue -name "DDRC_T_RAS" -value [expr int(ceil([ui::getValue -name "GUI_DDR3_TRAS"] * 1000 / double($mem_clk_period_ps)))]
        ui::setValue -name "DDRC_T_RP" -value [expr int(ceil([ui::getValue -name "GUI_DDR3_TRP"] * 1000 / double($mem_clk_period_ps)))]
        ui::setValue -name "DDRC_T_RCD" -value [expr int(ceil([ui::getValue -name "GUI_DDR3_TRCD"] * 1000 / double($mem_clk_period_ps)))]
        ui::setValue -name "DDRC_T_RTP" -value [expr int(ceil([ui::getValue -name "GUI_DDR3_TRTP"] * 1000 / double($mem_clk_period_ps)))]
        if {[ui::getValue -name "DDRC_T_RTP"] < 4} {
            ui::setValue -name "DDRC_T_RTP" -value 4
        }
        ui::setValue -name "DDRC_T_WR" -value [expr int(ceil([ui::getValue -name "GUI_DDR3_TWR"] * 1000 / double($mem_clk_period_ps)))]
        ui::setValue -name "DDRC_T_WTR" -value [expr int(ceil([ui::getValue -name "GUI_DDR3_TWTR"] * 1000 / double($mem_clk_period_ps)))]
        if {[ui::getValue -name "DDRC_T_WTR"] < 4} {
            ui::setValue -name "DDRC_T_WTR" -value 4
        }
    }
    ui::setValue -name "PHY_TXPR" -value [expr int(ceil(([ui::getValue -name "tRFC_MIN"] + 10000) / $dfi_clk_period))]
    ui::setValue -name "PHY_TRFC" -value [expr int(ceil([ui::getValue -name "tRFC_MIN"] / double($dfi_clk_period)))]
    ui::setValue -name "DDRC_TRFC" -value [expr int(ceil([ui::getValue -name "tRFC_MIN"] / double($mem_clk_period_ps)))]
    ui::setValue -name "DDRC_TREFI" -value [expr int([ui::getValue -name "tREFI"] * 1000 / $mem_clk_period_ps)]
    ui::setValue -name "DDRC_T_FAW" -value [expr int(45000 / $mem_clk_period_ps)]
    ui::setValue -name "DDRC_T_XP" -value [expr int(ceil(7500 / double($mem_clk_period_ps)))]
    if {[ui::getValue -name "DDRC_T_XP"] < 3} {
        ui::setValue -name "DDRC_T_XP" -value 3
    }
    ui::setValue -name "DDRC_T_RC" -value [expr int(ceil(50000 / double($mem_clk_period_ps)))]
    ui::setValue -name "DDRC_T_RRD" -value [expr int(ceil(10000 / double($mem_clk_period_ps)))]
}

proc check_dm_group_en {} {
    if { [ui::getDevice] == "PGL25G" } {
        if {[ui::getPackage] == "FBG484"} {
            ui::setValue -name "DM_GROUP_EN" -value 0
        } else {
            ui::setValue -name "DM_GROUP_EN" -value 1
        }
    } else {
        ui::setValue -name "DM_GROUP_EN" -value 0
    }

}

proc check_pin_all_dq_dqs_dm {} {
    set total_dq_width [ui::getValue -name "MEM_DQ_WIDTH"]
    set total_dqs_width [ui::getValue -name "MEM_DQS_WIDTH"]
    set total_dm_width [ui::getValue -name "MEM_DM_WIDTH"]
    set total_dq_dqs_dm_width [expr $total_dq_width + 2*$total_dqs_width]
    set dqs_cnt 0
    for {set i 0} {$i <= [expr $total_dq_width - 1]} {incr i} {
        set group_num [expr $i/8]
        set dq_num [expr $i%8]
        if {$dq_num == 0} {
            set dqs_cnt 0
        }
        set group_goal [ui::getPkgPins -bank [ui::getValue -name "BANK_DQG_${group_num}"] -group [ui::getValue -name "GROUP_DQG_${group_num}"]]
        ui::setValue -name "DQS_TEST" -value [lindex $group_goal $dq_num]
        ui::setValue -name "DQS_IS" -value [ui::isPkgPinDQS -name [ui::getValue -name "DQS_TEST"]]
        if {[ui::getValue -name "DQS_IS"] == "0"} {
           if {$dqs_cnt == 2} {
                set loc [expr $dq_num + 2]
            } else {
                set loc $dq_num
            }
        } else {
            incr dqs_cnt
            set loc [expr $dq_num + 2]
        }
        check_pin_dq_dqs_dm [ui::getValue -name "BANK_DQG_${group_num}"] [ui::getValue -name "GROUP_DQG_${group_num}"] "DQ${i}" $loc
    }

    set dqs_cnt 0
    for {set i 0} {$i <= [expr $total_dq_dqs_dm_width - 1]} {incr i} {
        set group_num [expr $i/10]
        set dq_num [expr $i%10]
        set loc $dq_num
        set group_goal [ui::getPkgPins -bank [ui::getValue -name "BANK_DQG_${group_num}"] -group [ui::getValue -name "GROUP_DQG_${group_num}"]]
        ui::setValue -name "DQS_TEST" -value [lindex $group_goal $loc]
        ui::setValue -name "DQS_IS" -value [ui::isPkgPinDQS -name [ui::getValue -name "DQS_TEST"]]
        if {[ui::getValue -name "DQS_IS"] == "1"} {
            incr dqs_cnt
            if {$dqs_cnt == 1} {
                check_pin_dq_dqs_dm [ui::getValue -name "BANK_DQG_${group_num}"] [ui::getValue -name "GROUP_DQG_${group_num}"] "DQSN${group_num}" $loc
            } elseif {$dqs_cnt == 2} {
                check_pin_dq_dqs_dm [ui::getValue -name "BANK_DQG_${group_num}"] [ui::getValue -name "GROUP_DQG_${group_num}"] "DQS${group_num}" $loc
                set dqs_cnt 0
            }
        }
    }

    for {set i 0} {$i <= [expr $total_dqs_width - 1]} {incr i} {
        check_pin_dq_dqs_dm [ui::getValue -name "BANK_DQG_${i}"] [ui::getValue -name "GROUP_DQG_${i}"] "DM${i}" 10
    }
}

proc check_pin_dq_dqs_dm {user_bank user_group pin_name dft_loc} {
    set group_default [ui::getPkgPins -bank $user_bank -group $user_group]
    ui::setValue -name "PAD_$pin_name" -value [lindex $group_default $dft_loc]
}

proc check_device_100H {} {
    if {[ui::getDevice] == "PGL100H"} {
        ui::setValue -name "DEVICE_100H" -value 1
    } else {
        ui::setValue -name "DEVICE_100H" -value 0
    }
}

###########################################################################################

