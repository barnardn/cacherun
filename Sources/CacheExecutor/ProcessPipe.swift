import Foundation

/// Sets up a pipe on stdin and stdout for a command process. One can execute the command and read the output
/// from the command's process on whichever pipe finishes first. Presumably sucess reads all from stout,
/// and fail reads all from stderr
///
public final class ProcessPipe {
    private let process: Process
    private let pipe: Pipe
    
    /// sets up a pipe for a process for reading
    /// - Parameters:
    ///   - commandURL: the url to the command to execute
    ///   - args: command line arguments to the command
    ///   - cwd: the working directory where the command is run from
    public init(commandURL: URL, args: [String], cwd: String = "/tmp") {
        let process = Process()
        process.executableURL = commandURL
        process.arguments = args
        process.currentDirectoryURL = URL(string: cwd)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        self.process = process
        self.pipe = pipe
    }
    
    /// reads from the command's pipe. blocks until the command exists. throws an error should something fail
    /// - Returns: an UTF8 string of the command's output (stdout or stderr)
    public func readAll() throws -> String? {
        try process.run()
        let data = try pipe.fileHandleForReading.readToEnd()
        process.waitUntilExit()

        guard let data else { return nil }

        return String(data: data, encoding: .utf8)
    }

    
    /// convenience method for creating a ProcessPipe
    /// - Parameters:
    ///   - cmd: url of the command to execute
    ///   - args: command line args to command
    ///   - cwd: current working directory for cmd
    /// - Returns: a ProcessPipe ready to run
    public static func popen(cmd: URL, args: [String] = [], cwd: String = "/tmp") -> ProcessPipe {
        Self(commandURL: cmd, args: args, cwd: cwd)
    }

}

