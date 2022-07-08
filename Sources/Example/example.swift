import ArgumentParser

@main
struct Example: ParsableCommand {

    static var configuration = CommandConfiguration(
        abstract: "An example program for Swift-UDS.",
        version: "0.1.0",
        subcommands: [OBD2.self]
    )

    struct Options: ParsableArguments {

        @Argument(help: "The URL to the adapter.")
        var url: String
    }

}
