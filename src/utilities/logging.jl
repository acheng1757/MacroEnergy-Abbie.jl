const date_format = "yyyy-mm-dd HH:MM:SS"

# Custom meta formatter that excludes the log level
function custom_meta_formatter(level, _module, group, id, file, line)
    return :nothing, ""  # Return empty metadata
end

# Custom transformer that adds timestamp
timestamp_logger(logger) = TransformerLogger(logger) do log
    merge(log, (; message = "$(Dates.format(now(), date_format)) $(log.message)"))
end

function set_logger(log_to_console::Bool, log_to_file::Bool, log_level::LogLevel, log_file_path::AbstractString)
        if !(log_to_console) && !(log_to_file)
            return nothing
        end
        loggers = []
        if log_to_console
            console_logger = 
            MinLevelLogger(
                ConsoleLogger(
                    stdout
                ), 
                log_level
            ) |> timestamp_logger
            push!(loggers, console_logger)
        end
        if log_to_file
            file_logger = MinLevelLogger(
                FileLogger(
                    log_file_path;
                    append = false,
                    always_flush = true, 
                ),
                log_level
            ) |> timestamp_logger
            push!(loggers, file_logger)
        end
        if length(loggers) == 1
            global_logger(loggers[1])
        else
            global_logger(TeeLogger(loggers...))
        end
        return nothing
    end