SRCS := ./bram.v \
	./kian_sim.v \
	../kianv_harris_edition/kianv_modified.v \
        ../kianv_harris_edition/control_unit.v  \
        ../kianv_harris_edition/datapath_unit.v \
        ../kianv_harris_edition/register_file.v \
        ../kianv_harris_edition/design_elements.v \
        ../kianv_harris_edition/design_elements_fpgacpu_ca.v \
        ../kianv_harris_edition/alu.v \
        ../kianv_harris_edition/main_fsm.v \
        ../kianv_harris_edition/extend.v \
        ../kianv_harris_edition/alu_decoder.v \
        ../kianv_harris_edition/store_alignment.v \
        ../kianv_harris_edition/store_decoder.v \
        ../kianv_harris_edition/load_decoder.v \
        ../kianv_harris_edition/load_alignment.v \
        ../kianv_harris_edition/multiplier_extension_decoder.v \
        ../kianv_harris_edition/divider.v \
        ../kianv_harris_edition/multiplier.v \
        ../kianv_harris_edition/divider_decoder.v \
        ../kianv_harris_edition/multiplier_decoder.v \
        ../kianv_harris_edition/csr_exception_handler.v \
        ../kianv_harris_edition/csr_decoder.v \
        ../kianv_harris_edition/sv32.v \
        ../kianv_harris_edition/sv32_table_walk.v \
        ../kianv_harris_edition/sv32_translate_instruction_to_physical.v \
        ../kianv_harris_edition/sv32_translate_data_to_physical.v \
        ../kianv_harris_edition/tag_ram.v
