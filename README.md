ggx_monitor
---------

![lmkr_ggx](/lmkr_ggx.png?raw=true "lmkr_ggx")

#### Various LMKR GeoGraphix Discovery administration utilities all-in-one.

LMKR's [GeoGraphix Discovery] Suite is a premier interpretation software package used by geoscientists and engineers in the E&P industry. At the heart of every Discovery project is a SAP (formerly Sybase) [SQLAnywhere] database. Even a modest environment may have dozens of projects containing millions of well and production records, and they are typically distributed across several project servers.

Use [ggx_monitor] to accomplish the following chores from its handy command line interface. Several options are run on weekly scheduled tasks and their results stored in a SQL Server database.

### Functionality

**ggx_temps**
Lists (and optionally deletes) temp tables in GeoGraphix projects that are usually leftover from client crashes and should be deleted.

**ggx_newlogs**
Collects digital logs from a specified number of days ago from GeoGraphix projects listed in the options.yml file and stores the results in the MS SQL Server GGX_NEWLOGS table.

**ggx_olds**
Collects files age/modified and other metadata from these data/metadata components:

    -t aoi   => check all areas of interest (default)
    -t layer => check all layers in all AOIs
    -t user  => scan User Files folder contents
    -t log   => scan for all activity/import logs

...from GeoGraphix project homes listed in the options.yml file. Results are optionally written to CSV file. Use the skip_days flag to ignore a number of days from the present and return only older data. For example: '-s 90' will only return data older than about three months.

**ggx_stats**
Collects lots of metadata stats from GeoGraphix projects, including: data counts, coordinate systems, interpreters and an activity score that reflects project use (active or stale). It stores stats in the MS SQL Server GGX_STATS table.

**ggx_alerts**
Checks GeoGraphix projects for a variety of problems, including: bloated gxdb.log files, file fragmentation, and invalid surface and bottom hole lat/lons and stores the results in the MS SQL Server GGX_ALERTS table.

---

###Configuration

Each of the above command line utilities would get tedious if you had to type all the paths manually, Instead, they can read from an options file containing all required arguments. This greatly facilitates scheduled maintenance tasks. See the `options.yml` file for an example.

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'ggx_monitor'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ggx_monitor


---
Note: this gem was only ever used internally for "private" use. If you find it useful, please let me know and I'll help you out with bugs, tests, etc.



[GeoGraphix Discovery]:http://www.lmkr.com/geographix
[ggx_monitor]:https://github.com/rbhughes/ggx_monitor




