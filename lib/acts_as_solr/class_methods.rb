require File.dirname(__FILE__) + '/index'

module ActsAsSolr #:nodoc:
  module ClassMethods
    # Finds instances of a model. Terms are ANDed by default, can be overwritten 
    # by using OR between terms
    # 
    # Here's a sample (untested) code for your controller:
    # 
    #  def search
    #    results = Book.find_by_solr params[:query]
    #  end
    # 
    # You can also search for specific fields by searching for 'field:value'
    # 
    # ====options:
    # offset:: - The first document to be retrieved (offset)
    # limit:: - The number of rows per page
    # order:: - Orders (sort by) the result set using a given criteria:
    #
    #             Book.find_by_solr 'ruby', :order => 'description asc'
    # 
    # field_types:: This option is deprecated and will be obsolete by version 1.0.
    #               There's no need to specify the :field_types anymore when doing a 
    #               search in a model that specifies a field type for a field. The field 
    #               types are automatically traced back when they're included.
    # 
    #                 class Electronic < ActiveRecord::Base
    #                   acts_as_solr :fields => [{:price => :range_float}]
    #                 end
    # 
    # facets:: This option argument accepts the following arguments:
    #          fields:: The fields to be included in the faceted search (Solr's facet.field)
    #                   Must be an array of either Symbols or Hashes with the field as keys.
    #                   With the Hash form, additional options can be provided for every field.
    #                   Possible options are :sort, :limit, :offset, :prefix, :mincount and
    #                   :missing. They work the same as the global options below.
    #          query:: The queries to be included in the faceted search (Solr's facet.query)
    #          zeros:: Display facets with count of zero. (true|false)
    #          sort:: Sorts the faceted resuls by highest to lowest count. (true|false)
    #          browse:: This is where the 'drill-down' of the facets work. Accepts an array of
    #                   fields in the format "facet_field:term"
    #          mincount:: Replacement for zeros (it has been deprecated in Solr). Specifies the
    #                     minimum count necessary for a facet field to be returned. (Solr's
    #                     facet.mincount) Overrides :zeros if it is specified. Default is 0.
    #          limit:: Limit the results returned for the facets
    #          offset:: Offset where to start returning facets, most useful together with :limit
    #
    #          dates:: Run date faceted queries using the following arguments:
    #            fields:: The fields to be included in the faceted date search (Solr's facet.date).
    #                     It may be either a String/Symbol or Hash. If it's a hash the options are the
    #                     same as date_facets minus the fields option (i.e., :start:, :end, :gap, :other,
    #                     :between). These options if provided will override the base options.
    #                     (Solr's f.<field_name>.date.<key>=<value>).
    #            start:: The lower bound for the first date range for all Date Faceting. Required if
    #                    :fields is present
    #            end:: The upper bound for the last date range for all Date Faceting. Required if
    #                  :fields is prsent
    #            gap:: The size of each date range expressed as an interval to be added to the lower
    #                  bound using the DateMathParser syntax.  Required if :fields is prsent
    #            hardend:: A Boolean parameter instructing Solr what do do in the event that
    #                      facet.date.gap does not divide evenly between facet.date.start and facet.date.end.
    #            other:: This param indicates that in addition to the counts for each date range
    #                    constraint between facet.date.start and facet.date.end, other counds should be
    #                    calculated. May specify more then one in an Array. The possible options are:
    #              before:: - all records with lower bound less than start
    #              after:: - all records with upper bound greater than end
    #              between:: - all records with field values between start and end
    #              none:: - compute no other bounds (useful in per field assignment)
    #              all:: - shortcut for before, after, and between
    #            filter:: Similar to :query option provided by :facets, in that accepts an array of
    #                     of date queries to limit results. Can not be used as a part of a :field hash.
    #                     This is the only option that can be used if :fields is not present.
    # 
    # Example:
    # 
    #   Electronic.find_by_solr "memory", :facets => {:zeros => false, :sort => true,
    #                                                 :query => ["price:[* TO 200]",
    #                                                            "price:[200 TO 500]",
    #                                                            "price:[500 TO *]"],
    #                                                 :fields => [:category, :manufacturer],
    #                                                 :browse => ["category:Memory","manufacturer:Someone"]}
    #
    # Example using per-field options:
    #
    #   Electronic.find_by_solr "memory", :facets => [{:fields => {:category => {:limit => 3, :mincount => 2}}}]
    #
    # Examples of date faceting:
    #
    #  basic:
    #    Electronic.find_by_solr "memory", :facets => {:dates => {:fields => [:updated_at, :created_at],
    #      :start => 'NOW-10YEARS/DAY', :end => 'NOW/DAY', :gap => '+2YEARS', :other => :before}}
    #
    #  advanced:
    #    Electronic.find_by_solr "memory", :facets => {:dates => {:fields => [:updated_at,
    #    {:created_at => {:start => 'NOW-20YEARS/DAY', :end => 'NOW-10YEARS/DAY', :other => [:before, :after]}
    #    }], :start => 'NOW-10YEARS/DAY', :end => 'NOW/DAY', :other => :before, :filter =>
    #    ["created_at:[NOW-10YEARS/DAY TO NOW/DAY]", "updated_at:[NOW-1YEAR/DAY TO NOW/DAY]"]}}
    #
    #  filter only:
    #    Electronic.find_by_solr "memory", :facets => {:dates => {:filter => "updated_at:[NOW-1YEAR/DAY TO NOW/DAY]"}}
    #
    #
    #
    # scores:: If set to true this will return the score as a 'solr_score' attribute
    #          for each one of the instances found. Does not currently work with find_id_by_solr
    # 
    #            books = Book.find_by_solr 'ruby OR splinter', :scores => true
    #            books.records.first.solr_score
    #            => 1.21321397
    #            books.records.last.solr_score
    #            => 0.12321548
    # 
    # lazy:: If set to true the search will return objects that will touch the database when you ask for one
    #        of their attributes for the first time. Useful when you're using fragment caching based solely on
    #        types and ids.
    #
    def find_by_solr(query, options={})
      solr_index.find_by_solr(query, options)
    end
    
    # Finds instances of a model and returns an array with the ids:
    #  Book.find_id_by_solr "rails" => [1,4,7]
    # The options accepted are the same as find_by_solr
    # 
    def find_id_by_solr(query, options={})
      solr_index.find_id_by_solr(query, options)
    end
    
    # This method can be used to execute a search across multiple models:
    #   Book.multi_solr_search "Napoleon OR Tom", :models => [Movie]
    # 
    # ====options:
    # Accepts the same options as find_by_solr plus:
    # models:: The additional models you'd like to include in the search
    # results_format:: Specify the format of the results found
    #                  :objects :: Will return an array with the results being objects (default). Example:
    #                               Book.multi_solr_search "Napoleon OR Tom", :models => [Movie], :results_format => :objects
    #                  :ids :: Will return an array with the ids of each entry found. Example:
    #                           Book.multi_solr_search "Napoleon OR Tom", :models => [Movie], :results_format => :ids
    #                           => [{"id" => "Movie:1"},{"id" => Book:1}]
    #                          Where the value of each array is as Model:instance_id
    # scores:: If set to true this will return the score as a 'solr_score' attribute
    #          for each one of the instances found. Does not currently work with find_id_by_solr
    # 
    #            books = Book.multi_solr_search 'ruby OR splinter', :scores => true
    #            books.records.first.solr_score
    #            => 1.21321397
    #            books.records.last.solr_score
    #            => 0.12321548
    # 
    def multi_solr_search(query, options = {})
      solr_index.multi_solr_search(query, options)
    end

    # returns the total number of documents found in the query specified:
    #  Book.count_by_solr 'rails' => 3
    # 
    def count_by_solr(query, options = {})        
      solr_index.count_by_solr(query, options)
    end
            
    # It's used to rebuild the Solr index for a specific model. 
    #  Book.rebuild_solr_index
    # 
    # If batch_size is greater than 0, adds will be done in batches.
    # NOTE: If using sqlserver, be sure to use a finder with an explicit order.
    # Non-edge versions of rails do not handle pagination correctly for sqlserver
    # without an order clause.
    # 
    # If a finder block is given, it will be called to retrieve the items to index.
    # This can be very useful for things such as updating based on conditions or
    # using eager loading for indexed associations.
    def rebuild_solr_index(batch_size=0, &finder)
      solr_index.rebuild_solr_index(batch_size, &finder)
    end
    
    protected
    
    def solr_index
      ActsAsSolr::Index.new(self)
    end
  end
  
end