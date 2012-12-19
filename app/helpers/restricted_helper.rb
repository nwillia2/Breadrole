module RestrictedHelper  
  def auth_link_to(*args, &block)
    showLink = show_link(*args, &block)    
    if showLink
      args = writeTitleToLink(*args)
      return link_to(*args, &block)
    else
      return getDefaultLinkText(*args)
    end
  end

  def auth_link_to_unless_current(*args, &block)
    showLink = show_link(*args, &block)    
    if showLink
      args = writeTitleToLink(*args)
      return link_to_unless_current(*args, &block)
    else
      return getDefaultLinkText(*args)
    end
  end
  
  def auth_button_to(*args, &block)
    showLink = show_link(*args, &block)    
    if showLink
      args = writeTitleToLink(*args)
      return button_to(*args, &block)
    else
      return getDefaultLinkText(*args)
    end
  end
  
  private
  def writeTitleToLink(*args)
    html_options = args.third || nil
    if html_options.blank?
      args += [{:title => args[0]}]
    else
      args.third[:title] = args.first      
    end
    return args
  end
  
  def show_link(*args, &block)
    showLink = true
    # this initial code is copied from the link_to source, so that auth_link_to can also cope with the different ways it can be called (e.g. with a block)
    if block_given?
      options      = args.first || {}
      html_options = args.second
      showLink = show_link(capture(&block), options, html_options)
    else      
      url = args.second
      html_options = args.third || {}
      if url.present?
        # we need to find the controller and action from the information we have in the url, we pass this to a routing function to give us the controller and action
        method = html_options[:method]
        method = "get" if method.blank?
        method = method.to_s
        routeHash = Rails.application.routes.recognize_path(url, :method => method)        
        if routeHash.present?
          controller = routeHash[:controller]
          action = routeHash[:action]
          recordId = routeHash[:id]                  
          if !controller.blank? && !action.blank?                              
            # we need to lookup the method and change our action accordingly           
            case method.to_s
              when "delete"
                action = "destroy"
              when "put"
                action = "update"
              when "post"
                action = "create"                
            end
            showLink = hasAccess({:returnBool => true, :controller => controller, :action => action, :recordId => recordId, :url => url, :routeHash => routeHash})
          end
        end
      end
    end
    return showLink
  end
  
  def getDefaultLinkText(*args)
    # we may want to return a default value
    # that value could just be some text, e.g. "Not Applicable"
    # it could also be another link, E.g. The show page 
    defaultText = ""
    html_options = args.third
    if html_options.present?
      if html_options[:include_default_text].present?
        defaultText = html_options[:include_default_text]
        if !defaultText.is_a? String          
          defaultText = t("common.nolink")
        end
      end
      if html_options[:include_default_path].present?
        # clear down the extra args and set up a new link with the default options
        args[1] = html_options[:include_default_path]
        args[2][:include_default_text] = nil
        args[2][:include_default_path] = nil
        defaultText = auth_link_to(*args)
      end       
    end
    return defaultText
  end
end