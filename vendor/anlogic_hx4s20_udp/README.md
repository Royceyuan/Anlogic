# Anlogic HX4S20 Ethernet reference subset

Source: the official `33_HX4S20_Etherent_test_01_02_final_1000` example in `DEMO_TD版本6.2.1.zip`.

The secondary-board project uses the retained TEMAC, RGMII, transmit/receive FIFO, RAM and clock modules for its gigabit Ethernet interface. `par_ph1demo/al_ip/TEMAC_CORE.ipc` references the accompanying `TEMAC_CORE_gate.v`; both are required.

The original encrypted UDP/IP stack is not retained. The active fixed-peer UDP and MBP1 implementation is in `src/ethernet/`, connected through `src/secondary/top_secondary_main5e_netdiag.v`.
