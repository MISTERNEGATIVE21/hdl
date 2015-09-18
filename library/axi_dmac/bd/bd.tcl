
proc init {cellpath otherInfo} {
	set ip [get_bd_cells $cellpath]

	bd::mark_propagate_override $ip \
		"ASYNC_CLK_REQ_SRC ASYNC_CLK_SRC_DEST ASYNC_CLK_DEST_REQ"

	# On ZYNQ the core is most likely connected to the AXI3 HP ports so use AXI3
	# as the default.
	set family [string tolower [get_property FAMILY [get_property PART [current_project]]]]
	if {$family == "zynq"} {
		set axi_protocol 1
	} else {
		set axi_protocol 0
	}

	set_property "CONFIG.DMA_AXI_PROTOCOL_SRC" $axi_protocol $ip
	set_property "CONFIG.DMA_AXI_PROTOCOL_DEST" $axi_protocol $ip
}

proc axi_dmac_detect_async_clk { cellpath ip param_name clk_a clk_b } {
	set param_src [get_property "CONFIG.$param_name.VALUE_SRC" $ip]
	if {[string equal $param_src "USER"]} {
		return;
	}

	set clk_domain_a [get_property CONFIG.CLK_DOMAIN $clk_a]
	set clk_domain_b [get_property CONFIG.CLK_DOMAIN $clk_b]
	set clk_freq_a [get_property CONFIG.FREQ_HZ $clk_a]
	set clk_freq_b [get_property CONFIG.FREQ_HZ $clk_b]
	set clk_phase_a [get_property CONFIG.PHASE $clk_a]
	set clk_phase_b [get_property CONFIG.PHASE $clk_b]

	# Only mark it as sync if we can make sure that it is sync, if the
	# relationship of the clocks is unknown mark it as async
	if {$clk_domain_a != {} && $clk_domain_b != {} && \
		$clk_domain_a == $clk_domain_b && $clk_freq_a == $clk_freq_b && \
		$clk_phase_a == $clk_phase_b} {
		set clk_async 0
	} else {
		set clk_async 1
	}

	set_property "CONFIG.$param_name" $clk_async $ip

#	if {$clk_async == 0} {
#		bd::send_msg -of $cellpath -type INFO -msg_id 1 -text "$clk_a and $clk_b are synchronous"
#	} else {
#		bd::send_msg -of $cellpath -type INFO -msg_id 1 -text "$clk_a and $clk_b are asynchronous"
#	}
}

proc propagate {cellpath otherinfo} {
	set ip [get_bd_cells $cellpath]
	set src_type [get_property CONFIG.DMA_TYPE_SRC $ip]
	set dest_type [get_property CONFIG.DMA_TYPE_DEST $ip]

	set req_clk [get_bd_pins "$ip/s_axi_aclk"]

	if {$src_type == 2} {
		set src_clk [get_bd_pins "$ip/fifo_wr_clk"]
	} elseif {$src_type == 1} {
		set src_clk [get_bd_pins "$ip/s_axis_aclk"]
	} else {
		set src_clk [get_bd_pins "$ip/m_src_axi_aclk"]
	}

	if {$dest_type == 2} {
		set dest_clk [get_bd_pins "$ip/fifo_rd_clk"]
	} elseif {$src_type == 1} {
		set dest_clk [get_bd_pins "$ip/m_axis_aclk"]
	} else {
		set dest_clk [get_bd_pins "$ip/m_dest_axi_aclk"]
	}

	axi_dmac_detect_async_clk $cellpath $ip "ASYNC_CLK_REQ_SRC" $req_clk $src_clk
	axi_dmac_detect_async_clk $cellpath $ip "ASYNC_CLK_SRC_DEST" $src_clk $dest_clk
	axi_dmac_detect_async_clk $cellpath $ip "ASYNC_CLK_DEST_REQ" $dest_clk $req_clk
}
