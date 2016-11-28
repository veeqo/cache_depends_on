cache_depends_on
================

A better way of controlling cache dependencies than `belongs_to :product, touch: true`


Example
-------

```ruby
class Author < ActiveRecord::Base
  has_many :artciles

  cache_depends_on :articles
end

class Artcile < ActiveRecord::Base
  belongs_to :rating

  cache_depends_on :rating
end

class Rating < ActiveRecord::Base
  has_one :article
end
```

`CacheDependsOn` can deal with any kinds of ActiveRecord associations.

...console/SQL log...


Important notes
---------------

### Cache invalidation always happens outside transaction

...why...

### Each row will be updated only ones per transaction if properly configured

If an Author has five articles and all of them are updated within a transaction, the Author will be updated *only once*.

...why it is important...
...how to establish 'ideal relationships' between ActiveRecord models.


How to install
--------------

Add the following to your `Gemfile`:

```ruby
gem 'cache_depends_on'
```

Development
-----------

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.


Contributing
------------

Bug reports and pull requests are welcome on GitHub at https://github.com/veeqo/cache_depends_on.



Sponsored by [Veeqo](https://github.com/veeqo)
