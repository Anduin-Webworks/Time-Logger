# Command reference

## Window commands

| Command | Behavior |
|---|---|
| `/timelogger` | Open the TimeLogger window. |
| `/tlog` | Open the TimeLogger window. |
| `/tl` | Open the window with no argument; otherwise show command help unless a supported subcommand is used. |

## Subscription test value

`/tl sub <days>` stores `TimeLoggerDB.subExpiresUnix` as the current synchronized time plus the specified number of days. Zero is accepted; negative values are rejected. The value is used to calculate the event-time `subActive` flag. This command changes local test/state data and is not an account billing operation.

Malformed or unsupported input prints the command help. The handler currently documents `/tl sub <days>` in that help text.

