require 'arg-parser'
require 'csv-diff-report'


class CSVDiff

    class CLI

        include ArgParser::DSL

        # Define an on_parse handler for field names or indexes. Splits the
        # supplied argument value on commas, and converts numbers to Fixnums.
        register_parse_handler(:parse_fields) do |val, arg, hsh|
            val.split(',').map{ |fld|
                case fld
                when /^\d+$/ then fld.to_i
                when /^:(.+)/ then $1.intern
                else fld
                end
            }
        end
        register_parse_handler(:parse_delimiter) do |val, arg, hsh|
            case val
            when /TAB/i, '\\t' then "\t"
            when /COMMA/i then ','
            else val
            end
        end

        title 'CSV-Diff'

        purpose <<-EOT
            Generate a diff report between two files using the CSV-Diff algorithm.
        EOT

        positional_arg :from, 'The file or dir to use as the left or from source in the diff'
        positional_arg :to, 'The file or dir to use as the right or to source in the diff'
        positional_arg :pattern, 'A file name pattern to use to filter matching files if a directory ' +
            'diff is being performed', default: '*'

        usage_break 'Source Options:'
        keyword_arg :file_types, 'A comma-separated list of file-type names (supports wildcards) to process. ' +
            'Requires the presence of a .csvdiff file in the FROM or current directory to define ' +
            'the file type patterns.',
            short_key: 't', on_parse: :split_to_array
        keyword_arg :exclude_pattern, 'A file name pattern of files to exclude from the diff if a directory ' +
            'diff is being performed.',
            short_key: 'x'
        keyword_arg :field_names, 'A comma-separated list of field names for each field in the source files.' +
            'Only required if the source files do not contain header rows, or to use different names for the fields.',
            short_key: 'f', on_parse: :split_to_array
        keyword_arg :key_fields, 'The key field name(s) or index(es). Short-hand for specifying parent and child' +
            'fields separately; assumes the child field is the last key field.',
            short_key: 'k', on_parse: :parse_fields
        keyword_arg :parent_fields, 'The parent field name(s) or index(es).',
            short_key: 'p', on_parse: :parse_fields
        keyword_arg :child_fields, 'The child field name(s) or index(es).',
            short_key: 'c', on_parse: :parse_fields
        keyword_arg :delimiter, 'The field delimiter used within the file; use TAB for tab-delimited.',
            short_key: 'd', default: ',', on_parse: :parse_delimiter
        keyword_arg :encoding, 'The encoding to use when opening the CSV files.',
            short_key: 'e'
        flag_arg :trim_whitespace, 'If true, trim leading/trailing whitespace before comparing fields.',
            short_key: 'w'
        flag_arg :ignore_header, 'If true, the first line in each source file is ignored; ' +
            'requires the use of the --field-names option to name the fields.',
            short_key: 'i'

        usage_break 'Diff Options:'
        flag_arg :ignore_case, 'If true, field comparisons are performed without regard to case.'
        flag_arg :diff_common_fields_only, 'If true, only fields in both files are compared.',
            short_key: 'C'
        keyword_arg :ignore_fields, 'The names or indexes of any fields to be ignored during the diff.',
            short_key: 'I', on_parse: :parse_fields
        flag_arg :ignore_adds, "If true, items in TO that are not in FROM are ignored.",
            short_key: 'A'
        flag_arg :ignore_deletes, "If true, items in FROM that are not in TO are ignored.",
            short_key: 'D'
        flag_arg :ignore_updates, "If true, changes to properties on existing items are ignored.",
            short_key: 'U'
        flag_arg :ignore_moves, "If true, changes in an item's position are ignored.",
            short_key: 'M'

        usage_break 'Output Options:'
        keyword_arg :format, 'The format in which to produce the diff report: HTML, XLSX, or TXT.',
            default: 'HTML', validation: /^(html|xlsx?|te?xt|csv)$/i
        keyword_arg :output, 'The path to save the diff report to. If not specified, the diff ' +
            'report will be placed in the same directory as the FROM file, and will be named ' +
            'Diff_<FROM>_to_<TO>.<FORMAT>',
            short_key: 'o'
        keyword_arg :output_fields, 'The names or indexes of the fields to include in the diff output.',
            short_key: 'O', on_parse: :parse_fields
        keyword_arg :include_matched, 'If true, fields that match on lines with differences are included ' +
            'in the diff output; by default, matching fields are not included in the diff output.'


        # Parses command-line options, and then performs the diff.
        def run
            if arguments = parse_arguments
                begin
                    process(arguments)
                rescue RuntimeError => ex
                    Console.puts ex.message, :red
                    exit 1
                end
            else
                if show_help?
                    show_help(nil, Console.width).each do |line|
                        Console.puts line, :cyan
                    end
                else
                    show_usage(nil, Console.width).each do |line|
                        Console.puts line, :yellow
                    end
                end
                exit 2
            end
        end


        # Process a CSVDiffReport using +arguments+ to determine all options.
        def process(arguments)
            options = {}
            exclude_args = [:from, :to, :delimiter, :ignore_case]
            arguments.each_pair do |arg, val|
                options[arg] = val if val && !exclude_args.include?(arg)
            end
            options[:csv_options] = {:col_sep => arguments.delimiter}
            options[:case_sensitive] = !arguments.ignore_case
            rep = CSVDiff::Report.new
            rep.diff(arguments.from, arguments.to, options)

            output_dir = FileTest.directory?(arguments.from) ?
                arguments.from : File.dirname(arguments.from)
            left_name = File.basename(arguments.from, File.extname(arguments.from))
            right_name = File.basename(arguments.to, File.extname(arguments.to))
            output = arguments.output ||
                "#{output_dir}/Diff_#{left_name}_to_#{right_name}.diff"
            rep.output(output, arguments.format)
        end

    end

end


if __FILE__ == $0
    CSVDiff::CLI.new.run
end
