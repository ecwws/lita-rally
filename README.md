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

```config.handlers.rally.api_version``` - API version, default 'v2.0'

```config.handlers.rally.read_only``` - disable commands that modifies objects


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

Find rally defects created/closed in certain date range

```
lita rally find defects <created|closed> in last <number> days
```

Find rally defects created/closed in last few days

```
lita rally query <type> <query_string>
```

Execute raw Rally API query with <type> and <query_string>

```
lita rally <start|pause|finish|accept|backlog> <FormattedID>
```

Move object between schedule states: **start** -> **In-Progress**, **pause** ->
**Defined**, **finish** -> **Completed**, **backlog** -> **Backlog**.

## License

[MIT](http://opensource.org/licenses/MIT)
