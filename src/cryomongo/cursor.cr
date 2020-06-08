require "bson"
require "./commands"

class Mongo::Cursor
  include Iterator(BSON)

  @@lock = Mutex.new(:reentrant)
  @closed = false
  @database : String
  @collection : String

  property server_description : SDAM::ServerDescription? = nil

  def initialize(@client : Mongo::Client, @cursor_id : Int64, namespace : String, @batch : Array(BSON), @await_time_ms : Int64? = nil)
    @database, @collection = namespace.split(".", 2)
  end

  def initialize(@client : Mongo::Client, result : Commands::Common::QueryResult, @await_time_ms : Int64? = nil)
    @cursor_id = result.cursor.id
    @batch = result.cursor.first_batch
    @database, @collection = result.cursor.ns.split(".", 2)
  end

  def next
    element = @batch.shift?
    return element if element

    if @cursor_id == 0
      Iterator::Stop::INSTANCE
    else
      reply = @client.command(
        Commands::GetMore,
        database: @database,
        collection: @collection,
        cursor_id: @cursor_id,
        max_time_ms: @await_time_ms,
        server_description: @server_description
      ).not_nil!
      @cursor_id = reply.cursor.id
      @batch = reply.cursor.next_batch
      self.next
    end
  end

  def close
    @@lock.synchronize {
      unless @closed || @cursor_id == 0
        @client.command(
          Commands::KillCursors,
          database: @database,
          collection: @collection,
          cursor_ids: [@cursor_id],
          server_description: @server_description
        )
        @closed = true
      end
    }
  rescue e
    # Ignore - client might be dead
  end

  def finalize
    close
  end
end

class Mongo::Cursor::Wrapper(T)
  include Iterator(T)
  def initialize(@cursor : Cursor)
  end

  def next
    if (elt = @cursor.next).is_a? Iterator::Stop
      elt
    else
      {% if T == BSON %}
        elt
      {% else %}
        T.from_bson elt
      {% end %}
    end
  end
end
