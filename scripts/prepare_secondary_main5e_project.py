from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
full = "--full" in sys.argv
name = "hx4s20_secondary_main5e" if full else "hx4s20_secondary_main5e_readonly"
top_name = "top_secondary_main5e" if full else "top_secondary_main5e_readonly"
source = (root / "hx4s20_secondary_native720_phase144.al").read_text(encoding="utf-8")
# TD project files use an unescaped ampersand in this attribute name.
tree = ET.ElementTree(ET.fromstring(source.replace("UsedInP&R", "UsedInP&amp;R")))
project = tree.getroot()
project.find("Name").text = name
sources = project.find("Source_Files")
verilog = sources.find("Verilog")
extra_sources = [
    "vendor/anlogic_hx4s20_udp/src/BUFGMUX.v",
    "vendor/anlogic_hx4s20_udp/src/clk_gen_rst_gen.v",
    "vendor/anlogic_hx4s20_udp/src/div_clk_gen.v",
    "vendor/anlogic_hx4s20_udp/src/IDDR.v",
    "vendor/anlogic_hx4s20_udp/src/ODDR.v",
    "vendor/anlogic_hx4s20_udp/src/RAMB16_S9_S9.v",
    "vendor/anlogic_hx4s20_udp/src/rgmii_interface.v",
    "vendor/anlogic_hx4s20_udp/src/rx_client_fifo.v",
    "vendor/anlogic_hx4s20_udp/src/temac_block.v",
    "vendor/anlogic_hx4s20_udp/src/temac_clk_gen.v",
    "vendor/anlogic_hx4s20_udp/src/tx_client_fifo.v",
    "vendor/anlogic_hx4s20_udp/src/tx_clk_en_gen.v",
    "vendor/anlogic_hx4s20_udp/src/udp_ip_protocol_stack_merge.enc.v",
    "vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/rx_pll.v",
    "vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/pll_gen.v",
    "src/ethernet/mdio_clause22_monitor.v",
    "src/ethernet/udp_echo_buffer.v",
    "src/ethernet/mbp1_fixed_udp.v",
    "src/ethernet/mbp1_codec.v",
    "src/ethernet/mbp1_main_endpoint.v",
    "src/ethernet/mbp1_secondary_endpoint.v",
    "src/secondary/top_secondary_main5e_netdiag.v",
    "src/secondary/secondary_main5e_status_adapter.v",
    "src/secondary/top_secondary_main5e_readonly.v",
]
if full:
    extra_sources += ["src/secondary/secondary_main5e_keys.v",
                      "src/secondary/secondary_main5e_engineering_overlay.v",
                      "src/secondary/top_secondary_main5e.v"]
for order, path in enumerate(extra_sources, 100):
    file = ET.SubElement(verilog, "File", Path=path)
    info = ET.SubElement(file, "FileInfo")
    for attr_name, value in (("UsedInSyn", "true"), ("UsedInP&R", "true"),
                        ("BelongTo", "design_1"), ("CompileOrder", str(order))):
        ET.SubElement(info, "Attr", Name=attr_name, Val=value)
for kind, path in (
    ("ADC_FILE", f"constraints/{top_name}.adc"),
    ("SDC_FILE", f"constraints/{top_name}.sdc"),
):
    sources.find(kind).find("File").set("Path", path)
ip_files = ET.SubElement(sources, "IP_FILE")
for order, path in enumerate((
    "vendor/anlogic_hx4s20_udp/par_ph1demo/al_ip/TEMAC_CORE.ipc",
), 200):
    file = ET.SubElement(ip_files, "File", Path=path)
    info = ET.SubElement(file, "FileInfo")
    for attr_name, value in (("UsedInSyn", "true"), ("UsedInP&R", "true"),
                        ("BelongTo", "design_1"), ("CompileOrder", str(order))):
        ET.SubElement(info, "Attr", Name=attr_name, Val=value)
top = project.find("TOP_MODULE")
top.find("LABEL").text = top_name
top.find("MODULE").text = top_name
ET.indent(tree, space="    ")
tree.write(root / f"{name}.al", encoding="UTF-8",
           xml_declaration=True)
