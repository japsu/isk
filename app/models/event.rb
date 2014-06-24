# ISK - A web controllable slideshow system
#
# Author::		Vesa-Pekka Palmu
# Copyright:: Copyright (c) 2012-2013 Vesa-Pekka Palmu
# License::		Licensed under GPL v3, see LICENSE.md


class Event < ActiveRecord::Base
		
	has_many :master_groups
	has_many :presentations
	has_many :schedules
	has_many :slides, through: :master_groups
	
	belongs_to :thrashed, class_name: 'ThrashGroup', foreign_key: 'thrashed_id'
	belongs_to :ungrouped, class_name: 'UnGroup', foreign_key: 'ungrouped_id'
	
	validates :name, uniqueness: true, presence: true
	validates :current, inclusion: { in: [true, false] }	
	validates :ungrouped, :thrashed, presence: true
	validate :ensure_one_current_event
	
	# Make sure there is only one current event
	before_save :set_current_event
	
	# Create the associated groups as needed and set their event_id
	before_validation :create_groups, on: :create
	after_create :set_group_event_ids
	
	FilePath = Rails.root.join 'data', 'events'
	
	#Default config for events
	DefaultConfig = {
		full: { # Full slide image size
			width:1280,
			height: 720
		},
		preview: { # Preview image size
			width: 225,
			height: 400
		},
		thumb: { # Small thumbnail size
			width: 128,
			height: 72
		},
		simple_editor: {
			heading: {
				x: 30,
				y: 100
			},
			body: {
				y: 200,
				margin_left: 30,
				margin_right: 30
			}
		},
		schedule: {
			items_per_slide: 9,
			wrap: {
				soft: 30,
				hard: 35
			},
			use_positions_from_simple: true,
			positions: {
				heading: {
					x: 30,
					y: 100,
					font_size: 80
				},
				subheader: {
					color: '#ffd700'
				},
				body: {
					x: 30,
					y: 200,
					font_size: 48
				}
			}
		}
	}
		
	#Finds the current event
	def self.current
		self.where(:current => true).first!
	end
	
	#### Per event configuration
	# TODO: Dynamic configuration instead of constant
	
	def picture_sizes
		h = Hash.new
		[:full, :preview, :thumb].each do |key|
			h[key] = [DefaultConfig[key][:width], DefaultConfig[key][:height]]
		end
		return h
	end
	
	private
	
	# Create the associated groups as needed
	def create_groups
		self.ungrouped = UnGroup.create(
			name: ('Ungrouped slides for ' + self.name)
		) if self.ungrouped.nil?
		self.thrashed = ThrashGroup.create(
			name: ('Thrashed slides for ' + self.name)
		) if self.thrashed.nil?
	end
	
	# Set the event associations on special groups
	def set_group_event_ids
		self.ungrouped.event_id = self.id
		self.ungrouped.save!
		self.thrashed.event_id = self.id
		self.thrashed.save!
	end
	
	#Callback that resets every other event to non-current when setting another as current one
	def set_current_event
		if self.current && self.changed.include?('current')
			Event.update_all :current => false
		end
	end
	
	#Validation that prevents clearing the current event -bit
	def ensure_one_current_event
		if !self.current && self.changed.include?('current')
			errors.add(:current, "^Must have one current event")
		end
	end
	
	def config
		return @_config ||= read_config
	end

	def read_config
    if !self.new_record? && File.exists?(config_filename)
      config = YAML.load(File.read(config_filename))
		end
		return config.blank? ? DefaultConfig : config
	end
	
	def write_config
		
	end
	
	def config_filename
		FilePath.join 'event_' + self.id.to_s + '_config.yml'
	end
	
end
