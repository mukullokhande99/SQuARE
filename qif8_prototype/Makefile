.PHONY: rom check sim clean
rom:
	python3 tools/generate_rom.py
check: rom
	python3 tools/check_model.py
sim: rom
	iverilog -g2012 -s tb_qif8_pe -o results/tb.vvp rtl/qif_h8_rom.sv rtl/qif8_pe.sv tb/tb_qif8_pe.sv
	vvp results/tb.vvp
clean:
	rm -f results/tb.vvp
