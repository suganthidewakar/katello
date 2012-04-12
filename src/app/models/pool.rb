#
# Copyright 2012 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'util/notices'

class Pool
  include Glue::Candlepin::Pool
  include LazyAccessor

  def index_options
    {
      "_type" => :pool
    }
  end

  def self.index_settings
    {
        "index" => {
            "analysis" => {
                "filter" => {
                    "ngram_filter"  => {
                        "type"      => "edgeNGram",
                        "side"      => "front",
                        "min_gram"  => 1,
                        "max_gram"  => 30
                    }
                },
                "analyzer" => {
                    "autcomplete_name_analyzer" => {
                        "type"      => "custom",
                        "tokenizer" => "keyword",
                        "filter"    => ["standard", "lowercase", "asciifolding", "ngram_filter"]
                    }
                }.merge(Katello::Search::custom_analzyers)
            }
        }
    }
  end

  def self.index_mapping
    {
      :pool => {
        :properties => {
          :name          => { :type=> 'string', :analyzer=>:kt_name_analyzer},
          :name_autocomplete  => { :type=> 'string', :analyzer=>'autcomplete_name_analyzer'},
          :name_sort    => { :type => 'string', :index=> :not_analyzed }
        }
      }
    }
  end

  def self.index
    "#{AppConfig.elastic_index}_pool"
  end

  def self.find cp_id
    pool_json = Candlepin::Pool.find(cp_id)
    Pool.new(pool_json) if not pool_json.nil?
  end

  def self.index_pools cp_pools
    pools = cp_pools.collect{ |cp_pool|
      pool = self.find(cp_pool['id'])
      yyy = pool.as_json
      xxx = pool.as_json.merge(pool.index_options)
      xxx
    }
    Tire.index Pool.index do
      create :settings => Pool.index_settings, :mappings => Pool.index_mapping
      import pools
    end if !pools.empty?
  end

  def self.search query, start, page_size, sort=[:name_sort, "ASC"]
    return [] if !Tire.index(self.index).exists?

    all_rows = query.blank? #if blank, get all rows

    search = Tire.search self.index do
      query do
        if all_rows
          all
        else
          string query, {:default_field=>'name'}
        end
      end

      if page_size > 0
       size page_size
       from start
      end

      sort { by sort[0], sort[1] } unless !all_rows
    end
    return search.results
  rescue
    return []
  end

end
