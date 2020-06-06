require "../spec_helper"
require "./spec_helper"

include Crud::Helpers

describe "Mongo CRUD" do
  before_all {
    `rm -Rf ./data`
    puts `mlaunch init --single`
  }

  %w(read write).each do |suite|
    context "[#{suite}]" do
      client = Mongo::Client.new

      Dir.glob "./spec/crud/tests/v1/#{suite}/*.json" do |file_path|
        test_file = JSON.parse(File.open(file_path) { |file|
          file.gets_to_end
        })

        tests = test_file["tests"].as_a
        data = test_file["data"].as_a.map {|elt| BSON.from_json(elt.to_json) }
        min_server_version = test_file["minServerVersion"]?.try(&.as_s) || "0.0.1"
        max_server_version = test_file["maxServerVersion"]?.try(&.as_s) || "0.0.1"
        collection_name = test_file["collection_name"]?.try(&.as_s) || "collection"
        database_name = test_file["database_name"]?.try(&.as_s) || "database"

        collection = client[database_name][collection_name]

        context "#{file_path}" do
          tests.each { |test|
            description = test["description"].as_s
            focus = test["focus"]?.try(&.as_bool) || false

            it "#{description} (#{file_path})", focus: focus do
              collection.delete_many(BSON.new)
              collection.insert_many(data) if data.size > 0

              operation = test["operation"].as_h
              arguments = operation["arguments"].as_h
              arguments["options"]?.try { |options|
                arguments = arguments.merge(options.as_h)
              }
              outcome = test["outcome"].as_h
              outcome_result = outcome["result"]?
              outcome_data = outcome.dig?("collection", "data").try &.as_a
              outcome_collection_name = outcome.dig?("collection", "name").try &.as_s
              operation_name = operation["name"].as_s

              # Arguments

              collation = arguments["collation"]?.try { |c|
                Mongo::Collation.from_bson(BSON.from_json(c.to_json))
              }
              filter = bson_arg "filter"
              update = bson_arg "update"
              replacement = bson_arg "replacement"
              document = bson_arg "document"
              documents = bson_array_arg "documents"
              upsert = bool_arg "upsert"
              sort = bson_arg "sort"
              projection = bson_arg "projection"
              hint = arguments["hint"]?.try { |h|
                next h.as_s if h.as_s?
                BSON.from_json(h.to_json)
              }
              pipeline = bson_array_arg "pipeline"
              array_filters = bson_array_arg "arrayFilters"
              skip = int32_arg "skip"
              limit = int32_arg "limit"
              batch_size = int32_arg "batchSize"
              single_batch = bool_arg "singleBatch"
              max_time_ms = int32_arg "maxTimeMs"
              read_concern = arguments["readConcern"]?.try { |r|
                Mongo::ReadConcern.from_bson(BSON.from_json(r.to_json))
              }
              write_concern = arguments["writeConcern"]?.try { |w|
                Mongo::WriteConcern.from_bson(BSON.from_json(w.to_json))
              }
              allow_disk_use = bool_arg "allowDiskUse"
              bypass_document_validation = bool_arg "bypassDocumentValidation"
              ordered = bool_arg "ordered"
              new_ = string_arg("returnDocument").try(&.== "After")
              fields = bson_arg "fields"

              result = case operation_name
              when "estimatedDocumentCount"
                collection.estimated_document_count(
                  max_time_ms: max_time_ms.try &.to_i64
                )
              when "countDocuments"
                collection.count_documents(
                  filter: filter,
                  skip: skip,
                  limit: limit,
                  collation: collation,
                  hint: hint,
                  max_time_ms: max_time_ms
                )
              when "count"
                # deprecated - not implemented
                next
              when "distinct"
                collection.distinct(
                  key: arguments["fieldName"].as_s,
                  filter: filter,
                  collation: collation
                )
              when "find"
                collection.find(
                  filter: filter.not_nil!,
                  sort: sort,
                  projection: projection,
                  hint: hint,
                  skip: skip,
                  limit: limit,
                  batch_size: batch_size,
                  single_batch: single_batch,
                  max_time_ms: max_time_ms.try &.to_i64,
                  collation: collation
                )
              when "aggregate"
                collection.aggregate(
                  pipeline: pipeline.not_nil!,
                  allow_disk_use: allow_disk_use,
                  batch_size: batch_size,
                  max_time_ms: max_time_ms,
                  bypass_document_validation: bypass_document_validation,
                  read_concern: read_concern,
                  collation: collation,
                  hint: hint,
                  write_concern: write_concern,
                )
              when "updateOne"
                collection.update_one(
                  filter: filter.not_nil!,
                  update: update.not_nil!,
                  upsert: upsert || false,
                  array_filters: array_filters,
                  collation: collation,
                  hint: hint,
                  ordered: ordered,
                  write_concern: write_concern,
                  bypass_document_validation: bypass_document_validation
                )
              when "updateMany"
                collection.update_many(
                  filter: filter.not_nil!,
                  update: update.not_nil!,
                  upsert: upsert || false,
                  array_filters: array_filters,
                  collation: collation,
                  hint: hint,
                  ordered: ordered,
                  write_concern: write_concern,
                  bypass_document_validation: bypass_document_validation
                )
              when "replaceOne"
                collection.replace_one(
                  filter: filter.not_nil!,
                  replacement: replacement.not_nil!,
                  upsert: upsert || false,
                  collation: collation,
                  hint: hint,
                  ordered: ordered,
                  write_concern: write_concern,
                  bypass_document_validation: bypass_document_validation
                )
              when "insertOne"
                collection.insert_one(
                  document: document.not_nil!,
                  write_concern: write_concern,
                  bypass_document_validation: bypass_document_validation
                )
              when "insertMany"
                collection.insert_many(
                  documents: documents.not_nil!,
                  ordered: ordered,
                  write_concern: write_concern,
                  bypass_document_validation: bypass_document_validation
                )
              when "deleteOne"
                collection.delete_one(
                  filter: filter.not_nil!,
                  collation: collation,
                  hint: hint,
                  ordered: ordered,
                  write_concern: write_concern
                )
              when "deleteMany"
                collection.delete_many(
                  filter: filter.not_nil!,
                  collation: collation,
                  hint: hint,
                  ordered: ordered,
                  write_concern: write_concern
                )
              when "findOneAndUpdate"
                collection.find_one_and_update(
                  filter: filter.not_nil!,
                  update: update.not_nil!,
                  sort: sort,
                  new: new_,
                  fields: fields,
                  upsert: upsert,
                  bypass_document_validation: bypass_document_validation,
                  write_concern: write_concern,
                  collation: collation,
                  array_filters: array_filters
                )
              when "findOneAndReplace"
                collection.find_one_and_replace(
                  filter: filter.not_nil!,
                  replacement: replacement.not_nil!,
                  sort: sort,
                  new: new_,
                  fields: fields,
                  upsert: upsert,
                  bypass_document_validation: bypass_document_validation,
                  write_concern: write_concern,
                  collation: collation,
                  array_filters: array_filters
                )
              when "findOneAndDelete"
                collection.find_one_and_delete(
                  filter: filter.not_nil!,
                  sort: sort,
                  new: new_,
                  fields: fields,
                  bypass_document_validation: bypass_document_validation,
                  write_concern: write_concern,
                  collation: collation
                )
              when "bulkWrite"
                requests = Array(Mongo::Bulk::WriteModel).new
                arguments["requests"].as_a.each { |req|
                  name = req["name"].as_s
                  arguments = req["arguments"].as_h
                  collation = arguments["collation"]?.try { |c|
                    Mongo::Collation.from_bson(BSON.from_json(c.to_json))
                  }
                  hint = arguments["hint"]?.try { |h|
                    next h.as_s if h.as_s?
                    BSON.from_json(h.to_json)
                  }
                  case name
                  when "insertOne"
                    requests << Mongo::Bulk::InsertOne.new(
                      document: bson_arg("document").not_nil!
                    )
                  when "deleteOne"
                    requests << Mongo::Bulk::DeleteOne.new(
                      filter: bson_arg("filter").not_nil!,
                      collation: collation,
                      hint: hint
                    )
                  when "deleteMany"
                    requests << Mongo::Bulk::DeleteMany.new(
                      filter: bson_arg("filter").not_nil!,
                      collation: collation,
                      hint: hint
                    )
                  when "replaceOne"
                    requests << Mongo::Bulk::ReplaceOne.new(
                      filter: bson_arg("filter").not_nil!,
                      replacement: bson_arg("replacement").not_nil!,
                      collation: collation,
                      hint: hint,
                      upsert: bool_arg("upsert")
                    )
                  when "updateOne"
                    requests << Mongo::Bulk::UpdateOne.new(
                      filter: bson_arg("filter").not_nil!,
                      update: bson_arg("update").not_nil!,
                      array_filters: bson_array_arg("arrayFilters"),
                      collation: collation,
                      hint: hint,
                      upsert: bool_arg("upsert")
                    )
                  when "updateMany"
                    requests << Mongo::Bulk::UpdateMany.new(
                      filter: bson_arg("filter").not_nil!,
                      update: bson_arg("update").not_nil!,
                      array_filters: bson_array_arg("arrayFilters"),
                      collation: collation,
                      hint: hint,
                      upsert: bool_arg("upsert")
                    )
                  end
                }
                collection.bulk_write(
                  requests: requests,
                  ordered: ordered.not_nil!,
                  bypass_document_validation: bypass_document_validation
                )
              else
                puts "Not supported: #{operation_name}"
              end

              if outcome_data
                outcome_collection = client[database_name][outcome_collection_name || collection_name]
                collection_data = outcome_collection.find.to_a
                outcome_data.to_json.should eq collection_data.to_json
              end

              if outcome_result
                if result.is_a? BSON
                  compare_json(outcome_result, JSON.parse(result.to_json))
                elsif result.is_a? Array
                  result.zip(outcome_result.as_a) { |v1, v2|
                    v1.to_s.should eq v2.to_s
                  }
                elsif result.is_a? Mongo::Cursor
                  results = result.map { |elt| elt }.to_a
                  results.zip(outcome_result.as_a) { |v1, v2|
                    v1.to_json.should eq v2.to_json
                  }
                elsif result.is_a? Mongo::Commands::Common::UpdateResult
                  matched_count = outcome.dig("result", "matchedCount").as_i
                  modified_count = outcome.dig("result", "modifiedCount").as_i
                  upserted_count = outcome.dig("result", "upsertedCount").as_i
                  upserted_id = outcome.dig?("result", "upsertedId")
                  result_upserted_count = result.upserted.try(&.size) || 0
                  result_upserted_id = result.upserted.try &.[0]?.try &._id
                  ((result.n || 0) - result_upserted_count).should eq matched_count
                  (result.n_modified || 0).should eq modified_count
                  result_upserted_count.should eq upserted_count
                  result_upserted_id.should eq upserted_id
                elsif result.is_a? Mongo::Commands::Common::InsertResult
                  inserted_count =
                    (outcome.dig?("result", "insertedCount").try &.as_i) ||
                    (outcome.dig?("result", "insertedId").try { 1 }) ||
                    (outcome.dig("result", "insertedIds").as_h.size)
                  result.n.should eq inserted_count
                elsif result.is_a? Mongo::Commands::Common::DeleteResult
                  deleted_count = outcome.dig?("result", "deletedCount").try &.as_i || 0
                  result.n.should eq deleted_count
                elsif result.is_a? Mongo::Bulk::WriteResult
                  result.n_inserted.should eq (outcome_result["insertedCount"]? || 0)
                  result.n_matched.should eq (outcome_result["matchedCount"]? || 0)
                  result.n_modified.should eq (outcome_result["modifiedCount"]? || 0)
                  result.n_removed.should eq (outcome_result["deletedCount"]? || 0)
                  result.n_upserted.should eq (outcome_result["upsertedCount"]? || 0)
                elsif result.responds_to? :to_bson
                  result.to_bson.to_json.should eq outcome["result"].to_json
                else
                  result.to_json.should eq outcome["result"].to_json
                end
              end
            end
          }
        end
      end
    end
  end

  after_all {
    puts `mlaunch stop`
    `rm -Rf ./data`
  }
end