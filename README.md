# lita-rally

A port of
[![Hubot-Rally] https://github.com/github/hubot-scripts/blob/master/src/scripts/rally.coffee]
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

## License

[MIT](http://opensource.org/licenses/MIT)
