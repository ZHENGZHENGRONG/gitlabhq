require 'spec_helper'

feature 'Setup Mattermost slash commands', feature: true do
  include WaitForAjax

  let(:user) { create(:user) }
  let(:project) { create(:empty_project) }
  let(:service) { project.create_mattermost_slash_commands_service }
  let(:mattermost_enabled) { true }

  before do
    Settings.mattermost['enabled'] = mattermost_enabled
    project.team << [user, :master]
    login_as(user)
    visit edit_namespace_project_service_path(project.namespace, project, service)
  end

  describe 'user visits the mattermost slash command config page', js: true do
    it 'shows a help message' do
      wait_for_ajax

      expect(page).to have_content("This service allows GitLab users to perform common")
    end

    it 'shows the token after saving' do
      token = ('a'..'z').to_a.join

      fill_in 'service_token', with: token
      click_on 'Save'

      value = find_field('service_token').value

      expect(value).to eq(token)
    end

    it 'shows the add to mattermost button' do
      expect(page).to have_link('Add to Mattermost')
    end

    it 'shows an explanation if user is a member of no teams' do
      stub_teams(count: 0)

      click_link 'Add to Mattermost'

      expect(page).to have_content('You aren’t a member of any team on the Mattermost instance')
      expect(page).to have_link('join a team', href: "#{Gitlab.config.mattermost.host}/select_team")
    end

    it 'shows an explanation if user is a member of 1 team' do
      stub_teams(count: 1)

      click_link 'Add to Mattermost'

      expect(page).to have_content('The team where the slash commands will be used in')
      expect(page).to have_content('This is the only available team.')
    end

    it 'shows a disabled prefilled select if user is a member of 1 team' do
      teams = stub_teams(count: 1)

      click_link 'Add to Mattermost'

      team_name = teams.first[1]['display_name']
      select_element = find('select#mattermost_team_id')
      selected_option = select_element.find('option[selected]')

      expect(select_element['disabled']).to be(true)
      expect(selected_option).to have_content(team_name.to_s)
    end

    it 'has a hidden input for the prefilled value if user is a member of 1 team' do
      teams = stub_teams(count: 1)

      click_link 'Add to Mattermost'

      expect(find('input#mattermost_team_id', visible: false).value).to eq(teams.first[0].to_s)
    end

    it 'shows an explanation user is a member of multiple teams' do
      stub_teams(count: 2)

      click_link 'Add to Mattermost'

      expect(page).to have_content('Select the team where the slash commands will be used in')
      expect(page).to have_content('The list shows all available teams.')
    end

    it 'shows a select with team options user is a member of multiple teams' do
      stub_teams(count: 2)

      click_link 'Add to Mattermost'

      select_element = find('select#mattermost_team_id')
      selected_option = select_element.find('option[selected]')

      expect(select_element['disabled']).to be(false)
      expect(selected_option).to have_content('Select team...')
      # The 'Select team...' placeholder is item `0`.
      expect(select_element.all('option').count).to eq(3)
    end

    it 'shows an error alert with the error message if there is an error requesting teams' do
      allow_any_instance_of(MattermostSlashCommandsService).to receive(:list_teams) { 'test mattermost error message' }

      click_link 'Add to Mattermost'

      expect(page).to have_selector('.alert')
      expect(page).to have_content('test mattermost error message')
    end

    def stub_teams(count: 0)
      teams = create_teams(count)

      allow_any_instance_of(MattermostSlashCommandsService).to receive(:list_teams) { teams }

      teams
    end

    def create_teams(count = 0)
      teams = {}

      count.times do |i|
        i += 1
        teams[i] = { id: i, display_name: i }
      end

      teams
    end

    describe 'mattermost service is not enabled' do
      let(:mattermost_enabled) { false }

      it 'shows the correct trigger url' do
        value = find_field('request_url').value

        expect(value).to match("api/v3/projects/#{project.id}/services/mattermost_slash_commands/trigger")
      end
    end
  end

  describe 'stable logo url' do
    it 'shows a publicly available logo' do
      expect(File.exist?(Rails.root.join('public/slash-command-logo.png')))
    end
  end
end
