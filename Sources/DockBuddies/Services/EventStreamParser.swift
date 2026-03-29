import Foundation

struct EventStreamParser {
    static func latestStatus(sessionDir: URL, tailLines: Int = 20) -> String? {
        let eventsFile = sessionDir.appendingPathComponent("events.jsonl")
        guard let data = try? Data(contentsOf: eventsFile),
              let content = String(data: data, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: .newlines).suffix(tailLines)

        for line in lines.reversed() {
            guard !line.isEmpty,
                  let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = json["type"] as? String else { continue }

            switch type {
            case "tool.execution_start":
                if let eventData = json["data"] as? [String: Any],
                   let toolName = eventData["toolName"] as? String {
                    return formatToolStatus(toolName)
                }
            case "skill.invoked":
                if let eventData = json["data"] as? [String: Any],
                   let skillName = eventData["skill"] as? String {
                    return skillName.uppercased()
                }
            case "subagent.started":
                if let eventData = json["data"] as? [String: Any],
                   let desc = eventData["description"] as? String {
                    return String(desc.prefix(20)).uppercased()
                }
            case "session.mode_changed":
                if let eventData = json["data"] as? [String: Any],
                   let mode = eventData["mode"] as? String {
                    return mode.uppercased()
                }
            case "assistant.turn_start":
                return "THINKING"
            default:
                continue
            }
        }
        return nil
    }

    private static func formatToolStatus(_ tool: String) -> String {
        switch tool {
        case "bash": return "RUNNING CMD"
        case "edit": return "EDITING"
        case "view": return "READING"
        case "grep": return "SEARCHING"
        case "glob": return "FINDING FILES"
        case "create": return "CREATING FILE"
        case "task": return "SUB-AGENT"
        case "web_search": return "WEB SEARCH"
        case "web_fetch": return "FETCHING"
        default:
            if tool.contains("github") { return "GITHUB API" }
            return String(tool.prefix(16)).uppercased()
        }
    }
}
