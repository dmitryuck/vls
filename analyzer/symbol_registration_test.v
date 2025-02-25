import os
import ast
import test_utils
import benchmark
import analyzer.an_test_utils
import analyzer { Collector, Runes, Store, SymbolAnalyzer, import_modules_from_tree, new_tree_cursor, setup_builtin }
import v.util.diff
import term

fn test_symbol_registration() {
	diff_cmd := diff.find_working_diff_command() or { '' }
	mut p := ast.new_parser()
	mut bench := benchmark.new_benchmark()
	vlib_path := os.join_path(os.dir(os.getenv('VEXE')), 'vlib')
	mut reporter := &Collector{}
	mut store := &Store{
		reporter: reporter
		default_import_paths: [vlib_path]
	}

	setup_builtin(mut store, os.join_path(vlib_path, 'builtin'))

	mut sym_analyzer := SymbolAnalyzer{
		context: store.default_context()
		is_test: true
	}

	test_files_dir := test_utils.get_test_files_path(@FILE)
	test_files := test_utils.load_test_file_paths(test_files_dir, 'symbol_registration') or {
		bench.fail()
		println(bench.step_message_fail(err.msg()))
		assert false
		return
	}

	bench.set_total_expected_steps(test_files.len)
	for test_file_path in test_files {
		bench.step()
		test_name := os.base(test_file_path)
		content := os.read_file(test_file_path) or {
			bench.fail()
			println(bench.step_message_fail('file $test_file_path is missing'))
			continue
		}

		src, expected := test_utils.parse_test_file_content(content)
		err_msg := if src.len == 0 || content.len == 0 {
			'file $test_name has empty content'
		} else {
			''
		}

		if err_msg.len != 0 || src.len == 0 {
			bench.fail()
			eprintln(bench.step_message_fail(err_msg))
			continue
		}

		println(bench.step_message('Testing $test_name'))
		tree := p.parse_string(source: src)
		mut cursor := new_tree_cursor(tree.root_node())
		sym_analyzer.context = store.with(file_path: test_file_path, text: Runes(src.runes()))
		import_modules_from_tree(sym_analyzer.context, tree, vlib_path)
		mut formatter := sym_analyzer.context.symbol_formatter(false)
		symbols := sym_analyzer.analyze_from_cursor(mut cursor)
		result := an_test_utils.sexpr_str_symbol_array(mut formatter, symbols).replace(') (',
			')\n(')
		expected_trimmed := test_utils.newlines_to_spaces(expected).replace(') (', ')\n(')
		term.clear_previous_line()
		if result != expected_trimmed {
			if diff_cmd.len != 0 {
				bench.fail()
				println(bench.step_message_fail(test_name))
				println(diff.color_compare_strings(diff_cmd, 'vls_symbol_registration_test',
					expected_trimmed, result))
			} else {
				assert result == expected_trimmed
			}
		} else {
			println(bench.step_message_ok(test_name))
		}

		store.delete(os.dir(test_file_path))
	}
	assert bench.nfail == 0
	bench.stop()
}
