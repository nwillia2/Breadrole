module Breadrole
  class RestrictedController < ::ApplicationController
    before_filter :current_user, :authorize, :hasAccess
    helper_method :hasAccess
  
    def authorize
        login_name = session[:eppn]
        unless login_name
          #Send to login which is secured by shib, this will set the eppn session
          #flash[:notice] = "Could not resolve your NetID, Please log in using Shibboleth"
          session[:requested_page] = request.fullpath
          redirect_to(:controller => :login, :action => :index )
          return
        end
        if @currentUser.blank?
          user = User.find(:first, :conditions => ["email = ?", login_name])
          unless user
            flash[:warning] = "You are not authorized to use this application"
            redirect_to(:controller => :studentcourses, :action => :index )
            return
          end
          session[:cas_user] = user.email.split("@")[0]
          @currentUser = user
        end
      end
  
    def hasAccess(options = {})
      hasAccess = false
      returnBool = false || options[:returnBool]
      recordId = nil
      if returnBool
        controller = options[:controller]
        action = options[:action]
        recordId = options[:recordId]
        url = options[:url]
        routeHash = options[:routeHash]
      else
        url = request.fullpath      
        controller = params[:controller]
        action = params[:action]
      end
    
      if !controller.blank? && !action.blank?
        case action
        when "create"
          method = :post
        when "update"
          method = :put
        when "delete"
          method = :delete
        else        
          if !["new", "edit", "index", "show"].include?(action)
            # custom actions
            method = :post
          else
            method = :get
          end
        end
        # Replace the rails action with the nice standard display actions
        action = action.gsub("show", "view").gsub("index", "list").gsub("new", "create").gsub("update", "edit").gsub("destroy", "delete")
        message = "Access Denied (#{controller} - #{action})"
        # we don't really need this now that this resides in restricted controller...
        opencontrollers = ["application", "restricted", "login", "dashboards", "studentcourses", "studentmodules", "mpawards", "mpmodules", "studentcoursespecifications", "mpprogrammes", "studentfeedbacks", "studentmodulespecifications", "autocompletes"]
        # Only block the default rails actions, this will allow all autocompletes and ajax functions to work
        blockedactions = ["view", "list", "create", "edit", "delete"]
        if !opencontrollers.include?(controller)        
          if @currentUser.present?
            #Get the requested control and action
            controlleraction = controller + "__" + action
            userSecurityRoles = @currentUser.securityroles
            if !userSecurityRoles.blank?
              # Check that the security roles allow access to the contoller and action
              # if the securityroles don't have an entry for this controller, consider it an closed controller
              if Securityrole.column_names.collect {|cn| cn.split("__")[0]}.include?(controller)
                # loop through all securityroles and don't set the message until we've gone through them all
                hasSpecificAccess = true
                userSecurityRoles.each do |r|
                  if blockedactions.include?(action)
                    hasAccess = r[controlleraction.to_s]
                  else
                    hasAccess = true                  
                  end
                  # don't allow access yet, need to see if there's any specific persmissions for this controller
                  # don't worry about specifics for sys admin
                  if hasAccess && r.id != Securityrole::SYSTEM_ADMIN
                    # resolve the url to get extra information, if we don't have a routeHash already                         
                    if routeHash.blank?
                      begin
                        routeHash = Rails.application.routes.recognize_path(url, :method => method)                      
                      rescue
                        # if the above fails, just try the default
                        routeHash = Rails.application.routes.recognize_path(url)
                      end
                    end
                    hasAccess = hasAccessRules(r, url, action, routeHash)
                    hasSpecificAccess = hasAccess
                  end
                  break if hasAccess
                end
                if !hasSpecificAccess
                  message += " (There are specific access rules on the requested page)"
                end
              else
                # if you want to allow access by default, add this line
                # hasAccess = true
              end
            end
          end        
        else
          # open controllers
          hasAccess = true
        end
      end
      if returnBool
        return hasAccess
      else
        if !hasAccess
          # If the security role is not allowed access then redirect to the dashbaord
          flash[:warning] = message        
          redirect_to dashboards_path
        end
      end
    end
  
    def auth_redirect_to(url, default_url)
      redirected = false
      routeHash = Rails.application.routes.recognize_path(url)        
      if routeHash.present?
        controller = routeHash[:controller]
        action = routeHash[:action]
        recordId = routeHash[:id]
        if controller.present? && action.present?
          if hasAccess({:returnBool => true, :controller => controller, :action => action, :recordId => recordId})
            redirected = true
            redirect_to(url)
          end
        end
      end
      if !redirected
        redirect_to(default_url)
      end
    end
  
    def current_user
      currentUserSet = false
      if @currentUser.present?
        if @currentUser.username == session[:cas_user]
          currentUserSet = true
        end
      end
      if !currentUserSet
        @currentUser = nil
        if !session[:cas_user].blank?
          user = User.find_by_username(session[:cas_user])
          if !user.blank?
            @currentUser = user
          end
        end    
      end
      return @currentUser
    end
  
    def logout
      #CASClient::Frameworks::Rails::Filter.logout(self)
      session[:cas_user] = nil
      session[:eppn] = nil
      flash[:notice] = "You have been successfully logged out of this application"
      redirect_to(root_path)
      return
    end  
  
    def has_role?(securityrole)        
      currentUser = current_user
      if currentUser.present?
        if securityrole.is_a? String
          if currentUser.securityroles.where(:rolename => securityrole).present?
            return true
          end
        else
          if currentUser.securityroles.where(:id => securityrole).present?
            return true
          end
        end      
      end
      return false
    end
  
    private  
    # method to deny customisable access rules outside of the normal built in security
    def hasAccessRules(userSecurityRole, url, security_action, routeHash)
      # even if we're allowed access from looking at the roles, there may be some cases where we'll want to restrict this further
      # for specific controllers...
      hasAccess = true
      id_param = :id
    
      # this is a hash of information about the url we are currently evaluating
      if routeHash.present?      
        # set some local vars
        controller = routeHash[:controller]
        # action is the rails action      
        action = routeHash[:action]
        # security_action is the action after translation into security role style actions. e.g. "view", "list" etc     
      
        # if user is in courses or various sub models of courses, then we need to throw them out if they aren't part of the course team
        check_controller = false
        if controller == "courses" && (security_action == "edit" || security_action == "create" || security_action == "delete")
          check_controller = true
        else
          if url.present?          
            # everything chained from courses, but not courses itself
            if url.include?("/courses/") && controller != "courses"
              if security_action == "edit" || security_action == "create" || security_action == "delete"
                check_controller = true
                id_param = :course_id
              end
            end
          end
        end    
        if check_controller
          course = Course.find(routeHash[id_param])            
          hasAccess = !is_course_readonly?(course)
        
          # valdoc workflow security
          # developing the validation document
          if hasAccess
            if controller == "valdocs"
              check_controller = true
            else 
              if url.present?
                if url.include?("/valdocs/") && controller != "valdocs"
                  check_controller = true              
                  id_param = :valdoc_id
                end
              end
            end      
            if check_controller
              hasAccess = check_valdoc(userSecurityRole, security_action, routeHash, id_param, controller)
            end
          end    
        end
      
        if hasAccess
          # courseproposal workflow security
          # developing the Course Proposal Form (CPF)
          if controller == "proposals"
            check_controller = true
          else 
            if url.present?
              if url.include?("/proposals/") && controller != "proposals"
                check_controller = true              
                id_param = :proposal_id
              end
            end
          end                          
          if check_controller    
            hasAccess = check_proposal(userSecurityRole, security_action, routeHash, id_param, controller)
          end
        end      
      end
    
      return hasAccess
    end
  
    # proposal methods
    def check_proposal(userSecurityRole, security_action, routeHash, id_param, controller)
      hasAccess = true
      proposal = Proposal.find(routeHash[id_param]) if routeHash[id_param].present?        
      if proposal.present?
        # if our proposal is closed or reversioned, only allow user to show or see the workflowprogress of the proposal            
        if !(controller == "proposals" && (security_action == "view" || security_action == "workflowprogress"))
          hasAccess = !(["Closed", "Reversioned", "Approved"].include?(proposal.proposalstatus.code))
          if hasAccess
            # if one of these security roles, we don't want to check any further
            if !([Securityrole::QUALITY_MANAGER, Securityrole::SAMI_USER, Securityrole::FINANCE_USER,
                Securityrole::EANDA_USER, Securityrole::ACADEMIC_REGISTRY_USER].include?(userSecurityRole.id))
    
              # if the user is one of the contacts, then they should have access                          
              hasAccess = is_proposal_contact?(proposal)
    
              # if the user STILL has access, make sure that they are not attempting to change any data in the cpf in the wrong state
              # we only need to put checks in where records can be changed out of state. So not for all controllers, but for the following...                          
              if hasAccess
                if security_action == "edit" || security_action == "create" || security_action == "delete"                
                  case controller
                    when "proposals", "facultyowners", "contacts", "courseproposalreviewgroups", "externalcompetitors", "externalcompetitionnotes", "courseproposalmarketresearches",
                         "coursecostings", "financerecommendations", "courseproposaldeliveries", "courseproposalstructures"
                      hasAccess = ([:proposal_started, :courseproposalsubmission_started, :courseproposalsubmission_restarted].include?(proposal.state_name))
                  end        
                elsif security_action == "list"                
                  if controller == "marketresearches"
                    hasAccess = ([:proposal_started, :courseproposalsubmission_started, :courseproposalsubmission_restarted].include?(proposal.state_name))
                  end
                elsif security_action == "start" || security_action == "end"
                  if controller == "courseproposalpeerreviewperiods"
                    # these actions are used on the peerreviewperiod screen and should only be available to the reporting officer (have to put this check here because we don't allow custom action roles)
                    hasAccess = (userSecurityRole.id == Securityrole::COURSE_PROPOSAL_REPORTING_OFFICER)
                  elsif controller == "courseproposalpeerreviewresponses"
                    hasAccess = (userSecurityRole.id == Securityrole::COURSE_PROPOSAL_DEVELOPMENT_TEAM)
                  end
                elsif controller == "proposals" && security_action == "refreshContacts"                  
                  # quality officers should be able to do this whenever they feel necessary
                  # course development team should also do this, but only at their stages
                  if ([:proposal_started, :courseproposalsubmission_started, :courseproposalsubmission_restarted].include?(proposal.state_name))
                    hasAccess = (userSecurityRole.id == Securityrole::COURSE_PROPOSAL_DEVELOPMENT_TEAM)
                  end
                end  
              end
            end
            # if we're adding / editing / removing comments, user should only be able to change their own              
            if hasAccess
              if controller == "courseproposalpeerreviewcomments"
                if security_action == "edit" || security_action == "delete"
                  comment = Comment.find(routeHash[:id])
                  if comment.present?
                    hasAccess = (@currentUser.id == comment.user_id)
                  end
                end
              end
            end
          end
        end
      end
      return hasAccess
    end
  
    def is_proposal_contact?(proposal)    
      if proposal.contacts.present?                   
        proposal.contacts.each do |pc|
          if @currentUser.username == pc.user.username
            # give this person access
            return true
          end
        end
      end
      # we haven't found the person in the standard list. Drill down into any groups this proposal is part of      
      if proposal.reviewgroups.present?
        proposal.reviewgroups.each do |rg|
          if rg.users.present?
            rg.users.each do |u|
              if @currentUser.username == u.username 
                return true
              end
            end
          end
        end
      end
      return false
    end
  
    # valdocs
    def check_valdoc(userSecurityRole, security_action, routeHash, id_param, controller)
      hasAccess = true
      valdoc = Valdoc.find(routeHash[id_param]) if routeHash[id_param].present?        
      if valdoc.present?
        # if our valdoc is closed, only allow user to show or see the workflowprogress of the valdoc
        if !(controller == "valdocs" && (security_action == "view" || security_action == "workflowprogress"))
          hasAccess = !(["Closed"].include?(valdoc.valdocstatus.code))
          if hasAccess
            # if one of these security roles, we don't want to check any further
            # if !([Securityrole::QUALITY_MANAGER, Securityrole::SAMI_USER, Securityrole::FINANCE_USER,
            #     Securityrole::EANDA_USER, Securityrole::ACADEMIC_REGISTRY_USER].include?(userSecurityRole.id))
            #     
            #   # if the user is one of the contacts, then they should have access                          
            #   hasAccess = is_proposal_contact?(proposal)
            #     
            #   # if the user STILL has access, make sure that they are not attempting to change any data in the cpf in the wrong state
            #   # we only need to put checks in where records can be changed out of state. So not for all controllers, but for the following...                          
            #   if hasAccess
            #     if security_action == "edit" || security_action == "create" || security_action == "delete"                
            #       case controller
            #         when "proposals", "facultyowners", "contacts", "courseproposalreviewgroups", "externalcompetitors", "externalcompetitionnotes", "courseproposalmarketresearches",
            #              "coursecostings", "financerecommendations", "courseproposaldeliveries", "courseproposalstructures"
            #           hasAccess = ([:proposal_started, :courseproposalsubmission_started, :courseproposalsubmission_restarted].include?(proposal.state_name))
            #       end        
            #     elsif security_action == "list"                
            #       if controller == "marketresearches"
            #         hasAccess = ([:proposal_started, :courseproposalsubmission_started, :courseproposalsubmission_restarted].include?(proposal.state_name))
            #       end
            #     elsif security_action == "start" || security_action == "end"
            #       if controller == "courseproposalpeerreviewperiods"
            #         # these actions are used on the peerreviewperiod screen and should only be available to the reporting officer (have to put this check here because we don't allow custom action roles)
            #         hasAccess = (userSecurityRole.id == Securityrole::COURSE_PROPOSAL_REPORTING_OFFICER)
            #       elsif controller == "courseproposalpeerreviewresponses"
            #         hasAccess = (userSecurityRole.id == Securityrole::COURSE_PROPOSAL_DEVELOPMENT_TEAM)
            #       end
            #     elsif controller == "proposals" && security_action == "refreshContacts"                  
            #       # quality officers should be able to do this whenever they feel necessary
            #       # course development team should also do this, but only at their stages
            #       if ([:proposal_started, :courseproposalsubmission_started, :courseproposalsubmission_restarted].include?(proposal.state_name))
            #         hasAccess = (userSecurityRole.id == Securityrole::COURSE_PROPOSAL_DEVELOPMENT_TEAM)
            #       end
            #     end  
            #   end
            # end
            # # if we're adding / editing / removing comments, user should only be able to change their own              
            # if hasAccess
            #   if controller == "courseproposalpeerreviewcomments"
            #     if security_action == "edit" || security_action == "delete"
            #       comment = Comment.find(routeHash[:id])
            #       if comment.present?
            #         hasAccess = (@currentUser.id == comment.user_id)
            #       end
            #     end
            #   end
            # end
          end
        end
      end
      return hasAccess
    end
  
    def is_course_readonly?(course)
      # if the current user is an admin, then allow access
      return false if has_role?(-1) || has_role?("Data Migration")
      res = true
      if !course.blank?
        course.coursecontacts.each do |contact|
          if contact.user_id == current_user.id
            res = false
            break
          end
        end
      end
      return res
    end
  end
end