# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2026_10_16_170000) do

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "line_items", force: :cascade do |t|
    t.integer "order_id"
    t.integer "quantity"
    t.decimal "price", precision: 6, scale: 2
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "description"
    t.decimal "amount"
  end

  create_table "orders", force: :cascade do |t|
    t.string "last_name"
    t.string "first_name"
    t.string "performance_code"
    t.string "venue"
    t.string "theater"
    t.string "title"
    t.string "credit_1"
    t.string "credit_2"
    t.string "patron_code"
    t.date "performance_date"
    t.time "performance_time"
    t.datetime "processed_on"
    t.decimal "amount", precision: 6, scale: 2
    t.string "status", default: "Unprinted"
    t.integer "remote_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "reprint_count", default: 0
    t.string "batch_id"
    t.integer "batch_sequence"
    t.string "print_status", default: "unprinted"
    t.text "print_error"
    t.datetime "printed_at"
    t.string "flags"
    t.index ["batch_id", "batch_sequence"], name: "index_orders_on_batch_id_and_batch_sequence"
    t.index ["batch_id"], name: "index_orders_on_batch_id"
    t.index ["print_status"], name: "index_orders_on_print_status"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "order_id"
    t.string "transaction_id"
    t.decimal "amount", precision: 6, scale: 2
    t.string "payment_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "print_batches", force: :cascade do |t|
    t.string "batch_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "order_count", default: 0
    t.integer "printed_count", default: 0
    t.integer "error_count", default: 0
    t.text "error_details"
    t.datetime "ready_at"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["batch_id"], name: "index_print_batches_on_batch_id", unique: true
    t.index ["created_at"], name: "index_print_batches_on_created_at"
    t.index ["status"], name: "index_print_batches_on_status"
  end

  create_table "tickets", force: :cascade do |t|
    t.integer "order_id"
    t.string "ticket_number"
    t.string "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "seat"
    t.string "ticket_class"
  end

end
