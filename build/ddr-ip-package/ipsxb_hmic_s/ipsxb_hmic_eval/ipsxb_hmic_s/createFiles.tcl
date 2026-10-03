    set nameInst    [ui::getInstName]
    set nameFamily  [ui::getFamily]
    set nameDevice  [ui::getDevice]
    set namePackage [ui::getPackage]
    set nameSpeed   [ui::getSpeedGrade]
    set pathInst    [ui::getInstPath]
    set toolVersion [ui::getToolVersion]
    set pathGTP     [ui::getModelPath]/../../../../../arch/vendor/pango/verilog/simulation
    set path_ip     [ui::getModelPath]
    regsub -all {\\} $pathGTP / pathGTP
    set mem_type [ui::getValue -name "MEM_TYPE"]
    set customize [ui::getValue -name "CUSTOMIZE_MEM"]

    set total_dq_width [ui::getValue -name "MEM_DQ_WIDTH"]
    set total_dqs_width [ui::getValue -name "MEM_DQS_WIDTH"]
    set ca_width [ui::getValue -name "MEM_ADDR_WIDTH"]
    set ba_width [ui::getValue -name "MEM_BANK_WIDTH"]
    set operating_mode [ui::getValue -name "OPERATING_MODE"]
    set clkin_freq [ui::getValue -name "CLKIN_FREQ"]
    set actual_rate [ui::getValue -name "ACTUAL_RATE"]
    set bank_ca [ui::getValue -name "BANK_CA"]
    set ca_group_num [ui::getValue -name "CA_GROUP_NUM"]
    set region_num [ui::getValue -name "REGION_NUM"]
    set device_100h [ui::getValue -name "DEVICE_100H"]
    set group_dq0 [ui::getValue -name "GROUP_DQG_0"]
    set group_dq1 [ui::getValue -name "GROUP_DQG_1"]
    set group_dq2 [ui::getValue -name "GROUP_DQG_2"]
    set group_dq3 [ui::getValue -name "GROUP_DQG_3"]
    set pad_mem_rst_n  [ui::getValue -name "PAD_RESET"]
    set pad_mem_cke  [ui::getValue -name "PAD_CKE"]
    set pad_mem_ck   [ui::getValue -name "PAD_CK"]
    set pad_mem_ck_n [ui::getValue -name "PAD_CKN"]
    set pad_mem_cs_n [ui::getValue -name "PAD_CS"]
    set pad_mem_ras_n  [ui::getValue -name "PAD_RAS"]
    set pad_mem_cas_n  [ui::getValue -name "PAD_CAS"]
    set pad_mem_we_n   [ui::getValue -name "PAD_WE"]
    set pad_mem_odt  [ui::getValue -name "PAD_ODT"]
    set pad_mem_ba0  [ui::getValue -name "PAD_BA0"]
    set pad_mem_ba1  [ui::getValue -name "PAD_BA1"]
    set pad_mem_ba2  [ui::getValue -name "PAD_BA2"]
    set pad_mem_a0   [ui::getValue -name "PAD_A0"]
    set pad_mem_a1   [ui::getValue -name "PAD_A1"]
    set pad_mem_a2   [ui::getValue -name "PAD_A2"]
    set pad_mem_a3   [ui::getValue -name "PAD_A3"]
    set pad_mem_a4   [ui::getValue -name "PAD_A4"]
    set pad_mem_a5   [ui::getValue -name "PAD_A5"]
    set pad_mem_a6   [ui::getValue -name "PAD_A6"]
    set pad_mem_a7   [ui::getValue -name "PAD_A7"]
    set pad_mem_a8   [ui::getValue -name "PAD_A8"]
    set pad_mem_a9   [ui::getValue -name "PAD_A9"]
    set pad_mem_a10  [ui::getValue -name "PAD_A10"]
    set pad_mem_a11  [ui::getValue -name "PAD_A11"]
    set pad_mem_a12  [ui::getValue -name "PAD_A12"]
    set pad_mem_a13  [ui::getValue -name "PAD_A13"]
    set pad_mem_a14  [ui::getValue -name "PAD_A14"]
    set pad_mem_a15  [ui::getValue -name "PAD_A15"]
    set pad_mem_dq0  [ui::getValue -name "PAD_DQ0"]
    set pad_mem_dq1  [ui::getValue -name "PAD_DQ1"]
    set pad_mem_dq2  [ui::getValue -name "PAD_DQ2"]
    set pad_mem_dq3  [ui::getValue -name "PAD_DQ3"]
    set pad_mem_dq4  [ui::getValue -name "PAD_DQ4"]
    set pad_mem_dq5  [ui::getValue -name "PAD_DQ5"]
    set pad_mem_dq6  [ui::getValue -name "PAD_DQ6"]
    set pad_mem_dq7  [ui::getValue -name "PAD_DQ7"]
    set pad_mem_dq8  [ui::getValue -name "PAD_DQ8"]
    set pad_mem_dq9  [ui::getValue -name "PAD_DQ9"]
    set pad_mem_dq10  [ui::getValue -name "PAD_DQ10"]
    set pad_mem_dq11  [ui::getValue -name "PAD_DQ11"]
    set pad_mem_dq12  [ui::getValue -name "PAD_DQ12"]
    set pad_mem_dq13  [ui::getValue -name "PAD_DQ13"]
    set pad_mem_dq14  [ui::getValue -name "PAD_DQ14"]
    set pad_mem_dq15  [ui::getValue -name "PAD_DQ15"]
    set pad_mem_dq16  [ui::getValue -name "PAD_DQ16"]
    set pad_mem_dq17  [ui::getValue -name "PAD_DQ17"]
    set pad_mem_dq18  [ui::getValue -name "PAD_DQ18"]
    set pad_mem_dq19  [ui::getValue -name "PAD_DQ19"]
    set pad_mem_dq20  [ui::getValue -name "PAD_DQ20"]
    set pad_mem_dq21  [ui::getValue -name "PAD_DQ21"]
    set pad_mem_dq22  [ui::getValue -name "PAD_DQ22"]
    set pad_mem_dq23  [ui::getValue -name "PAD_DQ23"]
    set pad_mem_dq24  [ui::getValue -name "PAD_DQ24"]
    set pad_mem_dq25  [ui::getValue -name "PAD_DQ25"]
    set pad_mem_dq26  [ui::getValue -name "PAD_DQ26"]
    set pad_mem_dq27  [ui::getValue -name "PAD_DQ27"]
    set pad_mem_dq28  [ui::getValue -name "PAD_DQ28"]
    set pad_mem_dq29  [ui::getValue -name "PAD_DQ29"]
    set pad_mem_dq30  [ui::getValue -name "PAD_DQ30"]
    set pad_mem_dq31  [ui::getValue -name "PAD_DQ31"]
    set pad_mem_dqs0  [ui::getValue -name "PAD_DQS0"]
    set pad_mem_dqs_n0 [ui::getValue -name "PAD_DQSN0"]
    set pad_mem_dqs1  [ui::getValue -name "PAD_DQS1"]
    set pad_mem_dqs_n1 [ui::getValue -name "PAD_DQSN1"]
    set pad_mem_dqs2  [ui::getValue -name "PAD_DQS2"]
    set pad_mem_dqs_n2 [ui::getValue -name "PAD_DQSN2"]
    set pad_mem_dqs3  [ui::getValue -name "PAD_DQS3"]
    set pad_mem_dqs_n3 [ui::getValue -name "PAD_DQSN3"]
    set pad_mem_dm0   [ui::getValue -name "PAD_DM0"]
    set pad_mem_dm1   [ui::getValue -name "PAD_DM1"]
    set pad_mem_dm2   [ui::getValue -name "PAD_DM2"]
    set pad_mem_dm3   [ui::getValue -name "PAD_DM3"]

    global clkoutfdiv
    global clkout0div
    global clkout1div

    proc get_pll_place {user_device user_package user_bank} {
        if {[ui::getDevice] == "PGL25G"} {
            set pll_place  PLL_122_75
        } elseif {[ui::getDevice] == "PGL50H"} {
            set pll_place  PLL_158_199
        } elseif {[ui::getDevice] == "PGL50G"} {
            set pll_place  PLL_158_199
        } elseif {[ui::getDevice] == "PGL100H"} {
            set pll_place  PLL_190_199
        }
        return $pll_place
    }
    
    proc get_pll_place_1 {user_device user_package user_bank} {
        if {[ui::getDevice] == "PGL50H"} {
            set pll_place_1  PLL_158_179
        } elseif {[ui::getDevice] == "PGL50G"} {
            set pll_place_1  PLL_158_179
        } elseif {[ui::getDevice] == "PGL100H"} {
            set pll_place_1  PLL_190_179
        } elseif {[ui::getDevice] == "PGL25G"} {
            set pll_place_1  PLL_122_75
        }
        return $pll_place_1
    }

      set fileCtrlPhyPGLPrj     [open $pathInst/pnr/$nameInst.pds w]
      puts $fileCtrlPhyPGLPrj "(_flow fab_demo \"$toolVersion\""
      puts $fileCtrlPhyPGLPrj "    (_comment \"Generated by Fabric Compiler on Tue Dec 01 16:03:40 2019\")"
      puts $fileCtrlPhyPGLPrj "    (_version \"1.0.5\")"
      puts $fileCtrlPhyPGLPrj "    (_status \"initial\")"
      puts $fileCtrlPhyPGLPrj "    (_project"
      puts $fileCtrlPhyPGLPrj "        (_option prj_work_dir (_string \"\"))"
      puts $fileCtrlPhyPGLPrj "        (_option prj_impl_dir (_string \"\"))"
      puts $fileCtrlPhyPGLPrj "    )"
      puts $fileCtrlPhyPGLPrj "    (_task tsk_setup"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_select_arch"
      puts $fileCtrlPhyPGLPrj "            (_input"
      puts $fileCtrlPhyPGLPrj "                (_part"
      puts $fileCtrlPhyPGLPrj "                    (_family $nameFamily)"
      puts $fileCtrlPhyPGLPrj "                    (_device $nameDevice)"
      puts $fileCtrlPhyPGLPrj "                    (_speedgrade $nameSpeed)"
      puts $fileCtrlPhyPGLPrj "                    (_package $namePackage)"
      puts $fileCtrlPhyPGLPrj "                )"
      puts $fileCtrlPhyPGLPrj "            )"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_my_design_src"
      puts $fileCtrlPhyPGLPrj "            (_input"

      set fList [open $pathInst/pnr/prj_filelist.f r]
      while {1} {
          set list [gets $fList]
          if {[eof $fList]} {
              close $fList
              break
          }

	  puts $fileCtrlPhyPGLPrj "                (_file \"$list\""
          puts $fileCtrlPhyPGLPrj "                    (_format verilog)"
          puts $fileCtrlPhyPGLPrj "                    (_timespec \"2019-12-01T15:23:47\")"
          puts $fileCtrlPhyPGLPrj "                )"
      }

      puts $fileCtrlPhyPGLPrj "                (_file \"../$nameInst.v\""
      puts $fileCtrlPhyPGLPrj "                    (_format verilog)"
      puts $fileCtrlPhyPGLPrj "                    (_timespec \"2019-12-01T15:23:47\")"
      puts $fileCtrlPhyPGLPrj "                )"
      puts $fileCtrlPhyPGLPrj "                (_file \"../$nameInst\_ddrphy_top.v\""
      puts $fileCtrlPhyPGLPrj "                    (_format verilog)"
      puts $fileCtrlPhyPGLPrj "                    (_timespec \"2019-12-01T15:23:47\")"
      puts $fileCtrlPhyPGLPrj "                )"

      puts $fileCtrlPhyPGLPrj "            )"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_my_ips_src"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_import_logic_con_file"
      puts $fileCtrlPhyPGLPrj "            (_input"
      puts $fileCtrlPhyPGLPrj "                (_file \"ddr_test.fdc\""
      puts $fileCtrlPhyPGLPrj "                    (_format fdc)"
      puts $fileCtrlPhyPGLPrj "                    (_timespec \"2018-12-01T15:23:47\")"
      puts $fileCtrlPhyPGLPrj "                )"
      puts $fileCtrlPhyPGLPrj "            )"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_edit_user_cons"
      puts $fileCtrlPhyPGLPrj "            (_attribute _click_to_run (_switch ON))"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_simulation"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "    )"
      puts $fileCtrlPhyPGLPrj "     (_task tsk_compile"
      puts $fileCtrlPhyPGLPrj "         (_command cmd_compile"
      puts $fileCtrlPhyPGLPrj "             (_gci_state (_integer 0))"
      puts $fileCtrlPhyPGLPrj "         )"
      puts $fileCtrlPhyPGLPrj "         (_widget wgt_rtl_view"
      puts $fileCtrlPhyPGLPrj "             (_attribute _click_to_run (_switch ON))"
      puts $fileCtrlPhyPGLPrj "         )"
      puts $fileCtrlPhyPGLPrj "     )"
      puts $fileCtrlPhyPGLPrj "    (_task tsk_synthesis"
      puts $fileCtrlPhyPGLPrj "        (_command cmd_synthesize"
      puts $fileCtrlPhyPGLPrj "        (_gci_state (_integer 4))"
      puts $fileCtrlPhyPGLPrj "            (_option ads (_switch ON))"
      puts $fileCtrlPhyPGLPrj "            (_option selected_syn_tool_opt (_integer 2))"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "       (_widget wgt_tech_view"
      puts $fileCtrlPhyPGLPrj "           (_attribute _click_to_run (_switch ON))"
      puts $fileCtrlPhyPGLPrj "       )"
      puts $fileCtrlPhyPGLPrj "       (_widget wgt_map_constraint"
      puts $fileCtrlPhyPGLPrj "       )"
      puts $fileCtrlPhyPGLPrj "       (_widget wgt_my_fic_src"
      puts $fileCtrlPhyPGLPrj "       )"
      puts $fileCtrlPhyPGLPrj "       (_widget wgt_inserter_gui_view"
      puts $fileCtrlPhyPGLPrj "           (_attribute _click_to_run (_switch ON))"
      puts $fileCtrlPhyPGLPrj "       )"
      puts $fileCtrlPhyPGLPrj "    )"
      puts $fileCtrlPhyPGLPrj "    (_task tsk_devmap"
      puts $fileCtrlPhyPGLPrj "        (_command cmd_devmap"
      puts $fileCtrlPhyPGLPrj "        (_gci_state (_integer 4))"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_edit_placement_cons"
      puts $fileCtrlPhyPGLPrj "            (_attribute _click_to_run (_switch ON))"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_edit_route_cons"
      puts $fileCtrlPhyPGLPrj "            (_attribute _click_to_run (_switch ON))"
      puts $fileCtrlPhyPGLPrj "            (_input"
      puts $fileCtrlPhyPGLPrj "                (_file \"$nameInst.rcf\""
      puts $fileCtrlPhyPGLPrj "                    (_format rcf)"
      puts $fileCtrlPhyPGLPrj "                    (_timespec \"2020-09-30T08:31:21\")"
      puts $fileCtrlPhyPGLPrj "                )"
      puts $fileCtrlPhyPGLPrj "            )"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "    )"
      puts $fileCtrlPhyPGLPrj "    (_task tsk_pnr"
      puts $fileCtrlPhyPGLPrj "        (_command cmd_pnr"
      puts $fileCtrlPhyPGLPrj "        (_gci_state (_integer 4))"
      puts $fileCtrlPhyPGLPrj "            (_option optimize_multi_corner_timing (_switch ON))"
      puts $fileCtrlPhyPGLPrj "            (_option fix_hold_violation (_switch ON))"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_command cmd_report_post_pnr_timing"
      puts $fileCtrlPhyPGLPrj "        (_gci_state (_integer 4))"
      puts $fileCtrlPhyPGLPrj "            (_attribute _auto_exe_lock (_switch OFF))"
      puts $fileCtrlPhyPGLPrj "            (_option configuration (_switch ON))"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "        (_widget wgt_arch_browser"
      puts $fileCtrlPhyPGLPrj "            (_attribute _click_to_run (_switch ON))"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "    )"
      puts $fileCtrlPhyPGLPrj "    (_task tsk_gen_bitstream"
      puts $fileCtrlPhyPGLPrj "        (_command cmd_gen_bitstream"
      puts $fileCtrlPhyPGLPrj "        (_gci_state (_integer 4))"
      puts $fileCtrlPhyPGLPrj "        )"
      puts $fileCtrlPhyPGLPrj "    )"
      puts $fileCtrlPhyPGLPrj ")"
      close $fileCtrlPhyPGLPrj 

      set filercf [open $pathInst/pnr/$nameInst.rcf w]
      if {$region_num > 2} {
          puts $filercf "def_route \-prior_net \{I_ipsxb_ddr_top/ddrphy_ioclk_gate\} \-load \{I_ipsxb_ddr_top/u_ipsxb_ddrphy_pll_0/u_pll_e3/goppll:CLKOUT0_SYN; I_ipsxb_ddr_top/u_ipsxb_ddrphy_pll_1/u_pll_e3/goppll:CLKOUT0_SYN; \}"
      } else {
          puts $filercf "def_route \-prior_net \{I_ipsxb_ddr_top/ddrphy_ioclk_gate\} \-load \{I_ipsxb_ddr_top/u_ipsxb_ddrphy_pll/u_pll_e3/goppll:CLKOUT0_SYN; \}"
      }
      close $filercf

      set prjList [open $pathInst/pnr/prj_filelist.f a]
      puts $prjList "../$nameInst.v"
      puts $prjList "../$nameInst\_ddrphy_top.v"
      close $prjList

      set ctrlphy_ipList [open $pathInst/pnr/ctrl_phy_ip_filelist.f a]
      puts $ctrlphy_ipList "$nameInst.v"
      puts $ctrlphy_ipList "$nameInst\_ddrphy_top.v"
      close $ctrlphy_ipList

      set phyonly_ipList [open $pathInst/pnr/phy_only_ip_filelist.f a]
      puts $phyonly_ipList "$nameInst\_ddrphy_top.v"
      close $phyonly_ipList

      set group_num [expr $total_dq_width / 8]

      set io_list [open $pathInst/pnr/io_list.f w]
      set ddrphy_top_io [open $pathInst/example_design/rtl/test_ddr.v r]
      while {1} {
        set top_io [gets $ddrphy_top_io]
        if {[eof $ddrphy_top_io]} {
          close $ddrphy_top_io
          break
        }
        if {[regexp "input" $top_io]} {
          regsub "input" $top_io "INPUT" updatevar
          puts $io_list $updatevar
        }
        if {[regexp "output" $top_io]} {
          regsub "output" $top_io "OUTPUT" updatevar
          puts $io_list $updatevar
        }
        if {[regexp "inout" $top_io]} {
          regsub "inout" $top_io "INOUT" updatevar
          puts $io_list $updatevar
        }
      }

      close $io_list

        set DDR_FDC [open $pathInst/pnr/ddr_test.fdc w]
        set clkin_period [expr double(1000.000/$clkin_freq)]
        set clkin_period_div2 [expr double($clkin_period/2.000)]
        puts $DDR_FDC "###==== BEGIN Clocks"
        puts $DDR_FDC "create_clock -name {ref_clk} \[get_ports {ref_clk}\] -period {$clkin_period\} -waveform {0 $clkin_period_div2\}"
        if {$device_100h == 1} {
            puts $DDR_FDC "create_clock -name {free_clk} \[get_ports {free_clk}\] -period \{10.000\} -waveform \{0.000 5.000\}"
        } else {
            puts $DDR_FDC "create_clock -name {free_clk} \[get_ports {free_clk}\] -period \{20.000\} -waveform \{0.000 10.000\}"
        }
        puts $DDR_FDC "###==== END Clocks"
        puts $DDR_FDC ""
        puts $DDR_FDC "###==== BEGIN \"Generated Clocks\""
        set clkoutfdiv [ui::getValue -name "STATIC_RATIOF"]
        set clkidiv [ui::getValue -name "STATIC_RATIOI"]
        set pllclkfdiv [expr ($clkoutfdiv)]
        set serclkdiv [expr ([ui::getValue -name "STATIC_RATIOI"] * [ui::getValue -name "STATIC_RATIO0"])]
        set pllout0div [expr (4 * [ui::getValue -name "STATIC_RATIOI"] * [ui::getValue -name "STATIC_RATIO0"])]

        puts $DDR_FDC "create_generated_clock -name {ddrphy_clkin} -source \[get_ports {ref_clk}\] \[get_pins {I_ipsxb_ddr_top.I_GTP_CLKDIV/CLKDIVOUT}\] -master_clock \[get_clocks {ref_clk}\] -multiply_by {$pllclkfdiv} -divide_by {$pllout0div}"
        puts $DDR_FDC "create_generated_clock -name {ioclk0} -source \[get_ports {ref_clk}\] \[get_pins {I_ipsxb_ddr_top.I_GTP_IOCLKBUF_0/CLKOUT}\] -master_clock \[get_clocks {ref_clk}\] -multiply_by {$pllclkfdiv} -divide_by {$serclkdiv}"
        if {$region_num > 1} {
            puts $DDR_FDC "create_generated_clock -name {ioclk1} -source \[get_ports {ref_clk}\] \[get_pins {I_ipsxb_ddr_top.I_GTP_IOCLKBUF_1/CLKOUT}\] -master_clock \[get_clocks {ref_clk}\] -multiply_by {$pllclkfdiv} -divide_by {$serclkdiv}"
        }
        if {$region_num > 2} {
            puts $DDR_FDC "create_generated_clock -name {ioclk2} -source \[get_ports {ref_clk}\] \[get_pins {I_ipsxb_ddr_top.I_GTP_IOCLKBUF_2/CLKOUT}\] -master_clock \[get_clocks {ref_clk}\] -multiply_by {$pllclkfdiv} -divide_by {$serclkdiv}"
        }
        puts $DDR_FDC "create_generated_clock -name {ioclk_gate_clk} -source \[get_ports {ref_clk}\] \[get_pins {I_ipsxb_ddr_top.u_clkbufg_gate/CLKOUT}\] -master_clock \[get_clocks {ref_clk}\] -multiply_by {$pllclkfdiv} -divide_by {$pllout0div}"
    
        set dq_g_num [expr $total_dq_width / 8]
        set group_list [list $group_dq0 $group_dq1 $group_dq2 $group_dq3]

        puts $DDR_FDC "###==== END \"Generated Clocks\""
        puts $DDR_FDC ""
        puts $DDR_FDC "###==== BEGIN \"Inputs/Outpusts\""
        puts $DDR_FDC "###==== END \"Inputs/Outpusts\""
        puts $DDR_FDC ""
        puts $DDR_FDC "###==== BEGIN \"Delay Paths\""
        puts $DDR_FDC "###==== END \"Delay Paths\""
        puts $DDR_FDC ""
        puts $DDR_FDC "###==== BEGIN \set_clock_group\""
        puts $DDR_FDC "set_clock_groups -name ref_clk -asynchronous -group \[get_clocks \{ref_clk\}\]"
        puts $DDR_FDC "set_clock_groups -name free_clk -asynchronous -group \[get_clocks \{free_clk\}\]"
        puts $DDR_FDC "set_clock_groups -name ioclk0 -asynchronous -group \[get_clocks \{ioclk0\}\]"
        puts $DDR_FDC "set_clock_groups -name ioclk1 -asynchronous -group \[get_clocks \{ioclk1\}\]"
        if {$region_num > 2} {
            puts $DDR_FDC "set_clock_groups -name ioclk2 -asynchronous -group \[get_clocks \{ioclk2\}\]"
        }
        puts $DDR_FDC "set_clock_groups -name ioclk_gate_clk -asynchronous -group \[get_clocks \{ioclk_gate_clk\}\]"

        puts $DDR_FDC "###==== END \"set_clock_group\""
        puts $DDR_FDC ""
        puts $DDR_FDC "###==== BEGIN \set_clock_uncertainty\""
        puts $DDR_FDC "set_clock_uncertainty \{0.200\} \[get_clocks \{ddrphy_clkin\}\]  -setup -hold"

        puts $DDR_FDC "###==== END \"set_clock_group\""
        puts $DDR_FDC ""
        puts $DDR_FDC "###==== BEGIN Attributes"
        set pll_place [get_pll_place $nameDevice $namePackage $bank_ca]        
        if {$region_num > 2} {
            set pll_place_1 [get_pll_place_1 $nameDevice $namePackage $bank_ca]
            puts $DDR_FDC "define_attribute \{i:I_ipsxb_ddr_top.u_ipsxb_ddrphy_pll_0.u_pll_e3\} \{PAP_LOC\} \{$pll_place\}"
            puts $DDR_FDC "define_attribute \{i:I_ipsxb_ddr_top.u_ipsxb_ddrphy_pll_1.u_pll_e3\} \{PAP_LOC\} \{$pll_place_1\}"
        } else {
            puts $DDR_FDC "define_attribute \{i:I_ipsxb_ddr_top.u_ipsxb_ddrphy_pll.u_pll_e3\} \{PAP_LOC\} \{$pll_place\}"
        }
        if {[ui::getDevice] == "PGL25G"} {
            puts $DDR_FDC "define_attribute \{i:I_ipsxb_ddr_top.u_ddrphy_top.ddrphy_reset_ctrl.ddrphy_ioclk_gate\} \{PAP_LOC\} \{CLMA_118_68:FF3\}"
        } elseif {([ui::getDevice] == "PGL50H") || ([ui::getDevice] == "PGL50G")} {
            puts $DDR_FDC "define_attribute \{i:I_ipsxb_ddr_top.u_ddrphy_top.ddrphy_reset_ctrl.ddrphy_ioclk_gate\} \{PAP_LOC\} \{CLMA_150_192:FF3\}"
        } elseif {[ui::getDevice] == "PGL100H"} {
            puts $DDR_FDC "define_attribute \{i:I_ipsxb_ddr_top.u_ddrphy_top.ddrphy_reset_ctrl.ddrphy_ioclk_gate\} \{PAP_LOC\} \{CLMA_186_192:FF3\}"
        }

        puts $DDR_FDC "###==== END Attributes"
        puts $DDR_FDC ""
        puts $DDR_FDC "###==== BEIN IO table"
        puts $DDR_FDC ""
        set ddr_iovcc 1.5
        set ref_clk_iostandard SSTL15D_I
        set ddr_dqs_iostandard SSTL15D_I
        set ddr_dq_iostandard SSTL15_I
        set ddr_ca_iostandard SSTL15_I
        set ddr_ck_iostandard SSTL15_I
        set ddr_io_drive 7.5

        ## read user fdc io constraint
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
        } elseif {[ui::getDevice] == "PGL100H"} {
            if {[ui::getPackage] == "FBG900"} {
                if {[ui::getValue -name "BANK_CA"] == "B1"} {
                    set user_fdc_file [open $path_ip/pnr/100h_ddr3_900_b1_x32.fdc r]
                } elseif {[ui::getValue -name "BANK_CA"] == "B3"} {
                    set user_fdc_file [open $path_ip/pnr/100h_ddr3_900_b3_x32.fdc r]
                }
            }
        }

        set find_pin_list [list ]

        while {[gets $user_fdc_file file_line] > -1} {
            # find PAP_IO_LOC line
            if {[regexp {^\ *define_attribute\ +\{p:([a-z0-9_]+)\[([0-9]+)\]\}\ +\{PAP_IO_([A-Z_]+)\}} $file_line match_string io_name io_num con_type]} {
                if {$io_name == "mem_a"} {
                    if {$io_num < $ca_width} {
                        if {$con_type == "LOC"} {
                            set pad_loc_var "pad_${io_name}${io_num}"
                            set pad_loc [set $pad_loc_var]
                            puts $DDR_FDC "define_attribute {p:${io_name}\[${io_num}\]} {PAP_IO_LOC} {${pad_loc}}"
                        } else {
                            puts $DDR_FDC $file_line
                        }
                    }
                } elseif {$io_name == "mem_dq"} {
                    if {$io_num < $total_dq_width} {
                        if {$con_type == "LOC"} {
                            set pad_loc_var "pad_${io_name}${io_num}"
                            set pad_loc [set $pad_loc_var]
                            puts $DDR_FDC "define_attribute {p:${io_name}\[${io_num}\]} {PAP_IO_LOC} {${pad_loc}}"
                        } else {
                            puts $DDR_FDC $file_line
                        }
                    }
                } elseif {$io_name == "mem_dqs" || $io_name == "mem_dqs_n" || $io_name == "mem_dm"} {
                    if {$io_num < $total_dqs_width} {
                        if {$con_type == "LOC"} {
                            set pad_loc_var "pad_${io_name}${io_num}"
                            set pad_loc [set $pad_loc_var]
                            puts $DDR_FDC "define_attribute {p:${io_name}\[${io_num}\]} {PAP_IO_LOC} {${pad_loc}}"
                        } else {
                            puts $DDR_FDC $file_line
                        }
                    }
                } elseif {$io_name == "mem_ba"} {
                    if {$con_type == "LOC"} {
                        set pad_loc_var "pad_${io_name}${io_num}"
                        set pad_loc [set $pad_loc_var]
                        puts $DDR_FDC "define_attribute {p:${io_name}\[${io_num}\]} {PAP_IO_LOC} {${pad_loc}}"
                    } else {
                        puts $DDR_FDC $file_line
                    }
                } else {
                    puts $DDR_FDC $file_line
                }
            } elseif {[regexp {^\ *define_attribute\ +\{p:([a-z0-9_]+)\}\ +\{PAP_IO_([A-Z_]+)\}} $file_line match_string io_name con_type]} {
                if {$io_name == "mem_cs_n"} {
                    if {[ui::getValue -name "CS_n_EN" ]} {
                        if {$con_type == "LOC"} {
                            set pad_loc_var "pad_${io_name}"
                            set pad_loc [set $pad_loc_var]
                            puts $DDR_FDC "define_attribute {p:${io_name}} {PAP_IO_LOC} {${pad_loc}}"
                        } else {
                            puts $DDR_FDC $file_line
                        }
                    }
                } elseif {$io_name == "mem_rst_n" || $io_name == "mem_ck" || $io_name == "mem_ck_n" || $io_name == "mem_cke" || $io_name == "mem_odt" || $io_name == "mem_ras_n" || $io_name == "mem_cas_n" || $io_name == "mem_we_n"} {
                    if {$con_type == "LOC"} {
                        set pad_loc_var "pad_${io_name}"
                        set pad_loc [set $pad_loc_var]
                        puts $DDR_FDC "define_attribute {p:${io_name}} {PAP_IO_LOC} {${pad_loc}}"
                    } else {
                        puts $DDR_FDC $file_line
                    }
                } else {
                    puts $DDR_FDC $file_line
                }
            }
        }
        close $user_fdc_file
        ## read dft fdc io constraint finish

        puts $DDR_FDC "###==== END Io Table"
        close $DDR_FDC

        #sim_file
        set SIM_FILE_LIST     [open $pathInst/sim/modelsim/sim_file_list.f w]
        if {$mem_type == "DDR3"} {
        puts $SIM_FILE_LIST "./../../example_design/bench/ddr3_tb/ddr_test_top_tb.v"
        puts $SIM_FILE_LIST "./../../example_design/bench/mem/ddr3.v"
        puts $SIM_FILE_LIST "./../../example_design/bench/mem/ddr3_parameters.vh"
        }
        puts $SIM_FILE_LIST "./../../example_design/rtl/axi_bist_top_v1_0.v"                                  
        puts $SIM_FILE_LIST "./../../example_design/rtl/prbs15_64bit_v1_0.v"                              
        puts $SIM_FILE_LIST "./../../example_design/rtl/prbs31_128bit_v1_0.v"                             
        puts $SIM_FILE_LIST "./../../example_design/rtl/test_ddr.v"                                       
        puts $SIM_FILE_LIST "./../../example_design/rtl/test_main_ctrl_v1_0.v"                            
        puts $SIM_FILE_LIST "./../../example_design/rtl/test_rd_ctrl_v1_0.v"                              
        puts $SIM_FILE_LIST "./../../example_design/rtl/test_wr_ctrl_v1_0.v"                              
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_rd_lock.v"                                   
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_clk_gen_32bit.v"            
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_cmd_parser_32bit.v"         
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_seu_rs232_intf.v"           
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_seu_uart_rx.v"              
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_seu_uart_tx.v"              
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_uart_ctrl_32bit.v"          
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_uart_ctrl_top_32bit.v"      
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_ver_ctrl_32bit.v"           

        puts $SIM_FILE_LIST "./../../rtl/ipsxb_rst_sync_v1_1.v"
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_calib_mux_v1_3.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_calib_top_v1_3.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_control_path_adj_v1_0.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_data_slice_v1_4.vp"                 
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_data_slice_dqs_gate_cal_v1_3.vp"    
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_data_slice_wrlvl_v1_4.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dfi_v1_4.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dll_update_ctrl_v1_0.vp"            
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dqsi_rdel_cal_v1_2.vp"              
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dqs_gate_coarse_cal_v1_3.vp"        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dqs_rddata_align_v1_3.vp"   
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_drift_ctrl_v1_3.vp"
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_gate_update_ctrl_v1_3.vp"
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_gatecal_v1_3.vp"                    
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_info_v1_0.vp"                       
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_init_v1_0.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_main_ctrl_v1_3.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_rdcal_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_reset_ctrl_v1_4.vp"                 
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_rst_debounce_v1_0.vp"          
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_slice_rddata_align_v1_0.vp"         
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_training_ctrl_v1_0.vp"              
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_upcal_v1_4.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_wdata_path_adj_v1_0.vp"             
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_wrlvl_v1_0.vp"                      
        puts $SIM_FILE_LIST "./../../rtl/ddrphy/ipsxb_ddrphy_slice_top_v1_4.v"             
        puts $SIM_FILE_LIST "./../../rtl/pll/ipsxb_ddrphy_pll_v1_0.v"
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_apb_cross_v1_2.vp"                    
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_calib_delay_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_cfg_apb_v1_2.vp"                         
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcd_bm_v1_2.vp"                    
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcd_rowaddr_v1_2.vp"                         
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcd_sm_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcd_top_v1_2.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcp_back_ctrl_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcp_buf_v1_2.vp"                 
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcp_out_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcp_top_v1_2.vp"              
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dfi_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_lp_v1_2.vp"                            
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_mrs_v1_2.vp"                             
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_prefetch_fifo_v1_2.vp"                            
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_rdatapath_v1_2.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_reg_fifo2_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_ui_axi_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_wdatapath_v1_2.vp"                         
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_wdp_align_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_wdp_dcp_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_wrapper_v1_2a.vp"                                              
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_com_timing_v1_2.vp"            
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_tfaw_timing_v1_2.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_tfaw_v1_2.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_act2wr_pass_v1_2.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_act_pass_v1_2.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_pre_pass_v1_2.vp"          
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_rd_pass_v1_2.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_ref_pass_v1_2.vp"       
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_wr_pass_v1_2.vp"        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_trc_timing_v1_2.vp"         
        puts $SIM_FILE_LIST "./../../rtl/mcdq_ctrl/distributed_fifo/ipsxb_distributed_fifo_v1_0.v"
        puts $SIM_FILE_LIST "./../../rtl/mcdq_ctrl/distributed_fifo/rtl/ipsxb_distributed_fifo_ctr_v1_0.v"
        puts $SIM_FILE_LIST "./../../rtl/mcdq_ctrl/distributed_fifo/rtl/ipsxb_distributed_fifo_v1_0_distributed_fifo_v1_0.v"
        puts $SIM_FILE_LIST "./../../rtl/mcdq_ctrl/distributed_fifo/rtl/ipsxb_distributed_sdpram_v1_0_distributed_fifo_v1_0.v"

        puts $SIM_FILE_LIST "$pathGTP\/GTP_DLL.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_DDC_E1.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_OSERDES.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_OUTBUFT.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_OUTBUFTCO.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_GRS.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_CLKBUFG.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_PLL_E3.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IOCLKBUF.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IOCLKDIV.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IOBUFCO.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IOBUF.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IODELAY.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_ISERDES.v"

        puts $SIM_FILE_LIST "./../../$nameInst.v"
        puts $SIM_FILE_LIST "./../../$nameInst\_ddrphy_top.v"
        puts $SIM_FILE_LIST " "

        puts $SIM_FILE_LIST "+define+SIMULATION  "
        if {$mem_type == "DDR3"} {
        puts $SIM_FILE_LIST "+define+den4096Mb   "
        puts $SIM_FILE_LIST "+define+sg25E       "
        puts $SIM_FILE_LIST "+define+x16         "
        } 
        close $SIM_FILE_LIST

        set SIM_FILE_LIST     [open $pathInst/sim/vcs/sim_file_list.f w]
        if {$mem_type == "DDR3"} {
        puts $SIM_FILE_LIST "./../../example_design/bench/ddr3_tb/ddr_test_top_tb.v"
        puts $SIM_FILE_LIST "./../../example_design/bench/mem/ddr3.v"
        puts $SIM_FILE_LIST "./../../example_design/bench/mem/ddr3_parameters.vh"
        }
        puts $SIM_FILE_LIST "./../../example_design/rtl/axi_bist_top_v1_0.v"                                  
        puts $SIM_FILE_LIST "./../../example_design/rtl/prbs15_64bit_v1_0.v"                              
        puts $SIM_FILE_LIST "./../../example_design/rtl/prbs31_128bit_v1_0.v"                             
        puts $SIM_FILE_LIST "./../../example_design/rtl/test_ddr.v"                                       
        puts $SIM_FILE_LIST "./../../example_design/rtl/test_main_ctrl_v1_0.v"                            
        puts $SIM_FILE_LIST "./../../example_design/rtl/test_rd_ctrl_v1_0.v"                              
        puts $SIM_FILE_LIST "./../../example_design/rtl/test_wr_ctrl_v1_0.v"                              
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_rd_lock.v"                                   
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_clk_gen_32bit.v"            
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_cmd_parser_32bit.v"         
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_seu_rs232_intf.v"           
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_seu_uart_rx.v"              
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_seu_uart_tx.v"              
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_uart_ctrl_32bit.v"          
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_uart_ctrl_top_32bit.v"      
        puts $SIM_FILE_LIST "./../../example_design/rtl/uart_ctrl_32bit/ipsxb_ver_ctrl_32bit.v"           

        puts $SIM_FILE_LIST "./../../rtl/ipsxb_rst_sync_v1_1.v"
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_calib_mux_v1_3.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_calib_top_v1_3.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_control_path_adj_v1_0.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_data_slice_v1_4.vp"                 
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_data_slice_dqs_gate_cal_v1_3.vp"    
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_data_slice_wrlvl_v1_4.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dfi_v1_4.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dll_update_ctrl_v1_0.vp"            
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dqsi_rdel_cal_v1_2.vp"              
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dqs_gate_coarse_cal_v1_3.vp"        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_dqs_rddata_align_v1_3.vp"   
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_drift_ctrl_v1_3.vp"
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_gate_update_ctrl_v1_3.vp"
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_gatecal_v1_3.vp"                    
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_info_v1_0.vp"                       
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_init_v1_0.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_main_ctrl_v1_3.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_rdcal_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_reset_ctrl_v1_4.vp"                 
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_rst_debounce_v1_0.vp"          
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_slice_rddata_align_v1_0.vp"         
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_training_ctrl_v1_0.vp"              
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_upcal_v1_4.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_wdata_path_adj_v1_0.vp"             
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/ddrphy/ipsxb_ddrphy_wrlvl_v1_0.vp"                      
        puts $SIM_FILE_LIST "./../../rtl/ddrphy/ipsxb_ddrphy_slice_top_v1_4.v"             
        puts $SIM_FILE_LIST "./../../rtl/pll/ipsxb_ddrphy_pll_v1_0.v"
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_apb_cross_v1_2.vp"                    
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_calib_delay_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_cfg_apb_v1_2.vp"                         
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcd_bm_v1_2.vp"                    
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcd_rowaddr_v1_2.vp"                         
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcd_sm_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcd_top_v1_2.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcp_back_ctrl_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcp_buf_v1_2.vp"                 
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcp_out_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dcp_top_v1_2.vp"              
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_dfi_v1_2.vp"                        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_lp_v1_2.vp"                            
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_mrs_v1_2.vp"                             
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_prefetch_fifo_v1_2.vp"                            
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_rdatapath_v1_2.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_reg_fifo2_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_ui_axi_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_wdatapath_v1_2.vp"                         
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_wdp_align_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_wdp_dcp_v1_2.vp"                      
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/ipsxb_mcdq_wrapper_v1_2a.vp"                                              
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_com_timing_v1_2.vp"            
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_tfaw_timing_v1_2.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_tfaw_v1_2.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_act2wr_pass_v1_2.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_act_pass_v1_2.vp"                  
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_pre_pass_v1_2.vp"          
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_rd_pass_v1_2.vp"           
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_ref_pass_v1_2.vp"       
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_timing_wr_pass_v1_2.vp"        
        puts $SIM_FILE_LIST "./../../sim_lib/rtl/mcdq_ctrl/syn_mod/ipsxb_mcdq_trc_timing_v1_2.vp"         
        puts $SIM_FILE_LIST "./../../rtl/mcdq_ctrl/distributed_fifo/ipsxb_distributed_fifo_v1_0.v"
        puts $SIM_FILE_LIST "./../../rtl/mcdq_ctrl/distributed_fifo/rtl/ipsxb_distributed_fifo_ctr_v1_0.v"
        puts $SIM_FILE_LIST "./../../rtl/mcdq_ctrl/distributed_fifo/rtl/ipsxb_distributed_fifo_v1_0_distributed_fifo_v1_0.v"
        puts $SIM_FILE_LIST "./../../rtl/mcdq_ctrl/distributed_fifo/rtl/ipsxb_distributed_sdpram_v1_0_distributed_fifo_v1_0.v"

        puts $SIM_FILE_LIST "$pathGTP\/GTP_DLL.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_DDC_E1.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_OSERDES.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_OUTBUFT.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_OUTBUFTCO.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_GRS.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_CLKBUFG.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_PLL_E3.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IOCLKBUF.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IOCLKDIV.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IOBUFCO.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IOBUF.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_IODELAY.v"
        puts $SIM_FILE_LIST "$pathGTP\/GTP_ISERDES.v"

        puts $SIM_FILE_LIST "./../../$nameInst.v"
        puts $SIM_FILE_LIST "./../../$nameInst\_ddrphy_top.v"
        puts $SIM_FILE_LIST " "

        puts $SIM_FILE_LIST "+define+SIMULATION  "
        if {$mem_type == "DDR3"} {
        puts $SIM_FILE_LIST "+define+den4096Mb   "
        puts $SIM_FILE_LIST "+define+sg25E       "
        puts $SIM_FILE_LIST "+define+x16         "
        } 

        close $SIM_FILE_LIST


        set SIM_TCL     [open $pathInst/sim/modelsim/sim.tcl w]

        puts $SIM_TCL "if {\[file exists work\]} {"
        puts $SIM_TCL "  file delete -force work  "
        puts $SIM_TCL "}"
        puts $SIM_TCL "vlib work"
        puts $SIM_TCL "vmap work work"
        puts $SIM_TCL ""
        if {$mem_type == "DDR3"} {
        puts $SIM_TCL "set LIB_DIR  $pathGTP"
        puts $SIM_TCL ""
        puts $SIM_TCL "vlib work"

        puts $SIM_TCL "vlog -sv -work work -mfcu -incr -f ../modelsim/sim_file_list.f -y $\LIB_DIR +libext+.v +incdir+../../example_design/bench/mem/ "
        puts $SIM_TCL "vsim -suppress 3486,3680,3781 +nowarn1 -c -sva -lib work ddr_test_top_tb -l sim.log"
        puts $SIM_TCL "run 800us"
        puts $SIM_TCL ""
        }
        close $SIM_TCL

        set SIM_TCL     [open $pathInst/sim/vcs/makefile w]
        if {$mem_type == "DDR3"} {
        puts $SIM_TCL "FUNC_DEF = +neg_tchk"
        puts $SIM_TCL "COMPILE_TOOL = vcs +systemverilogext+.sv+vpi -sverilog +v2k -ntb_opts dtm"
        puts $SIM_TCL "COMPILE_OPTS = +vcsd +vcs+lic+wait -lca -R"
        puts $SIM_TCL "COMPILE_OPTS += -full64 -P \$\{Verdi_HOME\}/share/PLI/VCS/linux64/novas.tab"
        puts $SIM_TCL "COMPILE_OPTS += \$\{Verdi_HOME\}/share/PLI/VCS/linux64/pli.a"
        puts $SIM_TCL "COMPILE_OPTS += -negdelay"
        puts $SIM_TCL "COMPILE_OPTS += +define+FSDB"
        puts $SIM_TCL "COMPILE_OPTS += -l ./sim.log"
        puts $SIM_TCL "COMPILE_OPTS += \$\{FUNC_DEF\}"
        puts $SIM_TCL ""
        puts $SIM_TCL ".PHONY:clean run_all"
        puts $SIM_TCL "run_all:"
        puts $SIM_TCL "	\$\{COMPILE_TOOL\} \$\{COMPILE_OPTS\} -f ./sim_file_list.f"
        puts $SIM_TCL "clean:"
        puts $SIM_TCL "	rm -rf *.log verdiLog simv.daidir novas.* csrc sdf_* simv ucli.key *.vf *.fsdb*"
        }
        close $SIM_TCL

        ui::clearSynSources
        ui::addSynSource -f $nameInst.v
        ui::addSynSource -f $nameInst\_ddrphy_top.v
        if {$operating_mode == "Controller + PHY"} {
            set ipcList [open $pathInst/pnr/ctrl_phy_ip_filelist.f r]
        } else {
            set ipcList [open $pathInst/pnr/phy_only_ip_filelist.f r]
        }
        while {1} {
              set list [gets $ipcList]
              if {[eof $ipcList]} {
                 close $ipcList
                 break
              }
	       ui::addSynSource -f $list
         }


         file delete -force $pathInst/pnr/ctrl_phy_ip_filelist.f
         file delete -force $pathInst/pnr/phy_only_ip_filelist.f
         file delete -force $pathInst/pnr/prj_filelist.f
         file delete -force $pathInst/pnr/io_list.f
         file delete -force $pathInst/pnr/25g_ddr3_256_b1_x16.fdc
         file delete -force $pathInst/pnr/25g_ddr3_256_b3_x16.fdc
         file delete -force $pathInst/pnr/25g_ddr3_324_b1_x16.fdc
         file delete -force $pathInst/pnr/25g_ddr3_324_b3_x16.fdc
         file delete -force $pathInst/pnr/25g_ddr3_484_b1_x32.fdc
         file delete -force $pathInst/pnr/25g_ddr3_484_b3_x32.fdc
         file delete -force $pathInst/pnr/50h_ddr3_mbg324_b1_x16.fdc
         file delete -force $pathInst/pnr/50h_ddr3_mbg324_b3_x16.fdc
         file delete -force $pathInst/pnr/50h_ddr3_mbg484_b1_x32.fdc
         file delete -force $pathInst/pnr/50h_ddr3_mbg484_b3_x32.fdc
         file delete -force $pathInst/pnr/50h_ddr3_fbg484_b1_x16.fdc
         file delete -force $pathInst/pnr/50h_ddr3_fbg484_b3_x32.fdc
         file delete -force $pathInst/pnr/50g_ddr3_mbg324_b1_x16.fdc
         file delete -force $pathInst/pnr/50g_ddr3_mbg324_b3_x16.fdc
         file delete -force $pathInst/pnr/50g_ddr3_fbg484_b1_x16.fdc
         file delete -force $pathInst/pnr/50g_ddr3_fbg484_b3_x32.fdc
         file delete -force $pathInst/pnr/50g_ddr3_mbg484_b1_x32.fdc
         file delete -force $pathInst/pnr/50g_ddr3_mbg484_b3_x32.fdc
         file delete -force $pathInst/pnr/50g_ddr3_fbg676_b1_x32.fdc
         file delete -force $pathInst/pnr/50g_ddr3_fbg676_b3_x32.fdc
         file delete -force $pathInst/pnr/100h_ddr3_900_b1_x32.fdc
         file delete -force $pathInst/pnr/100h_ddr3_900_b3_x32.fdc


