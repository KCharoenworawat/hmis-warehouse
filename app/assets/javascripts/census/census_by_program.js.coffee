#= require ./namespace

class App.Census.CensusByProgram extends App.Census.Base
  _build_census: () ->
    id = 0
    for data_source, all_organizations of @data
      for organization, all_projects of all_organizations
        for project, data of all_projects

          options = {}
          census_detail_slug = "#{data_source}-#{organization}-#{project}"
          @_individual_chart(data, id, census_detail_slug, options)
          id += 1        
