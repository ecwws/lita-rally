# lita-rally

A port of
[Hubot-Rally](https://github.com/github/hubot-scripts/blob/master/src/scripts/rally.coffee)
with some enhancements. 

## Installation

Add lita-rally to your Lita instance's Gemfile:

``` ruby
gem "lita-rally"
```


## Configuration

**Required:**

```config.handlers.rally.username``` - Rally username

```config.handlers.rally.password``` - Rally password

**Optional:**

```config.handlers.rally.api_version``` - API version. **Default:** 'v2.0'

```config.handlers.rally.read_only``` - [true/false] disable commands
that modifies objects. **Default:** false

```config.handlers.rally.action_state_map``` - [Hash] a map of actions to the
corresponding states of the artifact. **Default:**

```ruby
{
  'start' => 'Submitted',
  'pause' => 'Submitted',
  'backlog' => 'Submitted',
  'finish' => 'Fixed',
  'accept' => 'Closed',
}
```

```config.handlers.rally.action_schedule_state_map``` - [Hash] a map of actions
to the corresponding schedule states of the artifact. **Default:**

```ruby
{
  'start' => 'In-Progress',
  'pause' => 'Defined',
  'finish' => 'Completed',
  'accept' => 'Accepted',
  'backlog' => 'Backlog',
}
```

```config.handlers.rally.action_task_state_map``` - [Hash] a map of actions to
the corresponding task state of the artifact. **Default:**

```ruby
{
  'start' => 'In-Progress',
  'pause' => 'Defined',
  'backlog' => 'Defined',
  'finish' => 'Completed',
  'accept' => 'Completed',
}
```

```config.handlers.rally.hipchat_token``` - [String] Hipchat token.
**Default:** nil

## Usage

```
lita rally me <FormattedID>
```
Show information about Rally object identified by FormattedID.

```
lita rally me release stats for <release_name>
```
Show defect and user story count for the release <release_name>

```
lita rally me release info for <release_name>
```
Show object IDs (defects, user story, etc.) for release <release_name>.

```
lita rally find <defect|defects|story|stories> <contain|contains> "<search
term>" in <name|description>
```
Find object with terms

```
lita rally find defects <created|closed> between <date1> and <date2>
```

Find rally defects created/closed in certain date range, date format can be
**yyyy-mm-dd** **yy-mm-dd** **yyyy/mm/dd** **yy/mm/dd** **mm/dd**

```
lita rally find defects <created|closed> in last <number> days
```

Find rally defects created/closed in last few days

```
lita rally query <type> <query_string>
```

Execute raw Rally API query with <type> and <query_string>

```
lita rally mine
```

**(HipChat Only, require hipchat_tocken config)** Look up all Rally objects
belongs to me. (Limited to type Defect, Story, Task) Look up involves using
HipChat to determine user's e-mail. HipChat user's registered e-mail must match
Rally user registered e-mail.

```
lita rally my <defect|defects|story|stories|task|tasks>
```

**(HipChat Only, require hipchat_tocken config)** Look up all Rally objects
belongs to me of specific type. (Limited to type Defect, Story, Task) Look up
involves using HipChat to determine user's e-mail. HipChat user's registered
e-mail must match Rally user registered e-mail.

```
lita rally for [@]mention
lita rally <defect|defects|story|stories|task|tasks> for [@]mention
```

**(HipChat Only, require hipchat_token config)** Similar to ```rally mine```
and ```rally my ...```, except it'll look up the @mention user instead of user
executed the command.

```
lita rally <start|pause|finish|accept|backlog> <FormattedID>
```

Move object between schedule states: **start** -> **In-Progress**, **pause** ->
**Defined**, **finish** -> **Completed**, **backlog** -> **Backlog**.

```
lita rally claim <FormattedID>
lita rally assign <FormattedID> to [@]mention
```

**(HipChat Only, require hipchat_token config)** claim a Rally object's
ownership or assign the object to another user.

## License

[MIT](http://opensource.org/licenses/MIT)
