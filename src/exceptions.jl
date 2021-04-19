struct PackageNotInRegistry <: Exception
    message::String
end
Base.show(io::IO, e::PackageNotInRegistry) = println(io, e.message)

struct NoUUIDMatch <: Exception
    message::String
end
Base.show(io::IO, e::NoUUIDMatch) = println(io, e.message)
