extends Control

@onready var file_load_arc: FileDialog = $FILELoadARC
@onready var file_load_folder: FileDialog = $FILELoadFOLDER
@onready var memory_usage: Label = $MemUsage

var folder_path: String
var selected_files: PackedStringArray
var chose_file: bool = false
var chose_folder: bool = false

func _process(_delta: float) -> void:
	var MEM: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2: float = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	memory_usage.text = str("%.3f MB / %.3f MB" % [MEM * 0.000001, MEM2 * 0.000001])
	
	if chose_file and chose_folder:
		extractArc()
		selected_files.clear()
		chose_file = false
		chose_folder = false


func extractArc() -> void:
	var in_file: FileAccess
	var out_file: FileAccess
	var buff: PackedByteArray
	var arc_name: String
	var arc_size: int
	var num_files: int
	var f_offset: int
	var f_name_off: int
	var f_name: String
	var f_size: int
	var tbl_start: int = 0x20
	var dir: DirAccess
	
	for i in range(selected_files.size()):
		in_file = FileAccess.open(selected_files[i], FileAccess.READ)
		arc_name = selected_files[i].get_file()
		var hdr_bytes: PackedByteArray = in_file.get_buffer(0x0F)
		var hdr_string: String = hdr_bytes.get_string_from_ascii()
		
		if hdr_string != "MMArchiver2.000":
			OS.alert("Not a valid mma header in %s.")
			in_file.close()
			continue
		
		in_file.seek(0x10)
		num_files = in_file.get_32()
		
		dir = DirAccess.open(folder_path)
		var file_start: int = (num_files * 0x110) + tbl_start
		for files in range(num_files):
			in_file.seek((files * 0x110) + tbl_start)
			var pos: int = in_file.get_position()
			
			f_name = in_file.get_line()
			
			in_file.seek(pos + 0x100)
			var unk_1: int = in_file.get_16()
			var unk_2: int = in_file.get_16()
			f_size = in_file.get_32()
			var flag: int = in_file.get_32()
			f_offset = in_file.get_32() + file_start
			
			in_file.seek(f_offset)
			buff = decompress_raw_zlib(in_file.get_buffer(f_size), 0x989680, true)
			
			dir.make_dir_recursive(folder_path + "/%s" % arc_name + "/%s" % f_name.get_base_dir())
			
			out_file = FileAccess.open(folder_path + "/%s" % arc_name + "/%s" % f_name, FileAccess.WRITE)
			out_file.store_buffer(buff)
			out_file.close()
			
			buff.clear()
			
			print("0x%08X 0x%08X /%s/%s" % [f_offset + file_start, f_size, folder_path, f_name])
	
	print_rich("[color=green]Finished![/color]")


func decompress_raw_zlib(compressed_data: PackedByteArray, dec_size: int, is_zlib: bool) -> PackedByteArray:
	var out: PackedByteArray
	var part: Array
	var bytes_left: int
	var gzip_stream: StreamPeerGZIP = StreamPeerGZIP.new()
	
	# This isn't fail safe, as this can write junk data on < 0x100 size items. Need a better method in the future.
	# Assume 10MB is the max decompressed size as we don't initially know it.
	
	gzip_stream.start_decompression(is_zlib, dec_size)
	if compressed_data.size() < 0x100:
		gzip_stream.put_data(compressed_data)
		part = gzip_stream.get_data(dec_size)
		out.append_array(part[1])
		gzip_stream.clear()
		return out
	gzip_stream.put_partial_data(compressed_data)
	part = gzip_stream.get_partial_data(0x400)
	out.append_array(part[1])
	bytes_left = gzip_stream.get_available_bytes()
	while bytes_left != 0:
		part = gzip_stream.get_partial_data(0x400)
		out.append_array(part[1])
		bytes_left = gzip_stream.get_available_bytes()
	gzip_stream.clear()
	return out
	
	
func _on_load_dat_pressed() -> void:
	file_load_arc.visible = true


func _on_file_load_folder_dir_selected(dir: String) -> void:
	folder_path = dir
	chose_folder = true


func _on_file_load_arc_files_selected(paths: PackedStringArray) -> void:
	file_load_arc.visible = false
	file_load_folder.visible = true
	chose_file = true
	selected_files = paths
