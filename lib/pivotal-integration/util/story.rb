# Git Pivotal Tracker Integration
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative 'util'
require 'highline/import'
require 'pivotal-tracker'

# Utilities for dealing with +PivotalTracker::Story+s
class PivotalIntegration::Util::Story

  def self.new(project, name, type)
    project.stories.create(name: name, story_type: type)
  end

  # Print a human readable version of a story.  This pretty prints the title,
  # description, and notes for the story.
  #
  # @param [PivotalTracker::Story] story the story to pretty print
  # @return [void]
  def self.pretty_print(story)
    print_label 'ID'
    print_value story.id

    print_label 'Project'
    print_value PivotalTracker::Project.find(story.project_id).account

    print_label LABEL_TITLE
    print_value story.name

    description = story.description
    if !description.nil? && !description.empty?
      print_label 'Description'
      print_value description
    end

    print_label 'Type'
    print_value story.story_type.titlecase

    print_label 'State'
    print_value story.current_state.titlecase

    print_label 'Estimate'
    print_value story.estimate == -1 ? 'Unestimated' : story.estimate

    PivotalTracker::Note.all(story).sort_by { |note| note.noted_at }.each_with_index do |note, index|
      print_label "Note #{index + 1}"
      print_value note.text
    end

    puts
  end

  # Assign story to pivotal tracker member.
  #
  # @param [PivotalTracker::Story] story to be assigned
  # @param [PivotalTracker::Member] assigned user
  # @return [void]
  def self.assign(story, username)
    puts "Story assigned to #{username}" if story.update(owned_by: username)
  end

  # Marks Pivotal Tracker story with given state
  #
  # @param [PivotalTracker::Story] story to be assigned
  # @param [PivotalTracker::Member] assigned user
  # @return [void]
  def self.mark(story, state)
    puts "Changed state to #{state}" if story.update(current_state: state)
  end

  def self.estimate(story, points)
    story.update(estimate: points)
  end

  def self.add_comment(story, comment)
    story.notes.create(text: comment)
  end

  # Selects a Pivotal Tracker story by doing the following steps:
  #
  # @param [PivotalTracker::Project] project the project to select stories from
  # @param [String, nil] filter a filter for selecting the story to start.  This
  #   filter can be either:
  #   * a story id: selects the story represented by the id
  #   * a story type (feature, bug, chore): offers the user a selection of stories of the given type
  #   * +nil+: offers the user a selection of stories of all types
  # @param [Fixnum] limit The number maximum number of stories the user can choose from
  # @return [PivotalTracker::Story] The Pivotal Tracker story selected by the user
  def self.select_story(project, filter = nil, limit = 5)
    if filter =~ /[[:digit:]]/
      story = project.stories.find filter.to_i
    else
      story = find_story project, filter, limit
    end

    story
  end

  private

  CANDIDATE_STATES = %w(rejected unstarted unscheduled).freeze

  LABEL_DESCRIPTION = 'Description'.freeze

  LABEL_TITLE = 'Title'.freeze

  LABEL_WIDTH = (LABEL_DESCRIPTION.length + 2).freeze

  CONTENT_WIDTH = (HighLine.new.output_cols - LABEL_WIDTH).freeze

  def self.print_label(label)
    print "%#{LABEL_WIDTH}s" % ["#{label}: "]
  end

  def self.print_value(value)
    value = value.to_s

    if value.blank?
      puts ''
    else
      value.scan(/\S.{0,#{CONTENT_WIDTH - 2}}\S(?=\s|$)|\S+/).each_with_index do |line, index|
        if index == 0
          puts line
        else
          puts "%#{LABEL_WIDTH}s%s" % ['', line]
        end
      end
    end
  end

  def self.find_story(project, type, limit)
    criteria = {
      :current_state => CANDIDATE_STATES
    }
    if type
      criteria[:story_type] = type
    end

    candidates = project.stories.all(criteria).sort_by{ |s| s.owned_by == @user ? 1 : 0 }.slice(0..limit)
    if candidates.length == 1
      story = candidates[0]
    else
      story = choose do |menu|
        menu.prompt = 'Choose story to start: '

        candidates.each do |story|
          name = story.owned_by ? '[%s] ' % story.owned_by : ''
          name += type ? story.name : '%-7s %s' % [story.story_type.upcase, story.name]
          menu.choice(name) { story }
        end
      end

      puts
    end

    story
  end
end
