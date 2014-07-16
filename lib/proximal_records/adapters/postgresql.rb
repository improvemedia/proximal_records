module ProximalRecords
  module Adapters
    module Postgresql
      def proximal_records(scope)
        klass = self.class

        orders = scope.orders.join(', ')

        orders = "OVER(#{"ORDER BY #{orders}" if orders.present?})"
        primary_key = "#{klass.table_name}.#{klass.primary_key}"
        with_near_by = scope.select("#{klass.table_name}.*, LAG(#{primary_key}) #{orders} AS previous_id, LEAD(#{primary_key}) #{orders} AS next_id")

        subquery = if Rails::VERSION::STRING >= '4.0'
          klass.connection.unprepared_statement{ with_near_by.to_sql }
        else
          with_near_by.to_sql
        end

        query = %Q{
          SELECT z.*
          FROM (#{subquery}) z
          WHERE #{klass.primary_key} = #{id}
          LIMIT 1
        }

        a = ActiveRecord::Base.connection.select_one(query)

        previous_record, next_record = [(klass.find_by_id(a['previous_id'])), (klass.find_by_id(a['next_id']))]

        case scope.count
          when 1
            [nil, nil]
          when 2
            [next_record || previous_record] * 2
          else
            [previous_record || scope.last, next_record || scope.first]
        end
      end
    end
  end
end
