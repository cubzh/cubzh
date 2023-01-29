package main

import (
// "regexp"
// "sort"
// "strings"
// "github.com/gosimple/slug"
)

// Module documents a module,
// based on code inline documentation
type Module struct {
	// By default not loaded from JSON,
	// if empty, using first encountered type name.
	Name string `json:"-"`

	// meta keywords
	Keywords []string `json:"keywords,omitempty"`

	// Types defined within module
	Types []*ModuleType `json:"types,omitempty"`

	// Generatl description can be just a text,
	// but it can also be enriched with medias, code samples, etc.
	Description []*ContentBlock `json:"description,omitempty"`

	// meta description, built from Description
	MetaDescription string `json:"-,omitempty"`

	// not set in JSON, set dynamically when parsing files
	ResourcePath string `json:"-"`
}

type ModuleType struct {
	// Type name.
	Name string `json:"name,omitempty"`
	// A description for a type can be just a text,
	// but it can also be enriched with medias, code samples, etc.
	Description []*ContentBlock `json:"description,omitempty"`
	//
	Properties []*ModuleProperty `json:"properties,omitempty"`
	//
	Functions []*ModuleFunction `json:"functions,omitempty"`
}

type ModuleFunction struct {
	// The name of the function.
	Name string `json:"name,omitempty"`
	// Using sets of parameters because the same function can accept several.
	// Event though there's only one in most cases.
	ParameterSets [][]*Parameter `json:"params,omitempty"`
	// A description for a function can be just a text,
	// but it can also be enriched with medias, code samples, etc.
	Description []*ContentBlock `json:"description,omitempty"`
	// Returned values (can be empty if the function does not return anything).
	Return []*ModuleValue `json:"ret,omitempty"`
}

func (f *ModuleFunction) Copy() *ModuleFunction {

	function := &ModuleFunction{
		Name:          f.Name,
		ParameterSets: make([][]*Parameter, 0),
		Description:   make([]*ContentBlock, 0),
		Return:        make([]*ModuleValue, 0),
	}

	for _, set := range f.ParameterSets {

		params := make([]*Parameter, 0)
		for _, param := range set {
			params = append(params, param.Copy())
		}

		function.ParameterSets = append(function.ParameterSets, set)
	}

	for _, block := range f.Description {
		function.Description = append(function.Description, block) // need copy?
	}

	for _, v := range f.Return {
		function.Return = append(function.Return, v.Copy())
	}

	return function
}

type Parameter struct {
	Name string `json:"name,omitempty"`
	// Using array because the same parameter can be of several types.
	// Event though there's only one in most cases.
	Types       []string `json:"types,omitempty"`
	Description string   `json:"description,omitempty"`
	Optional    bool     `json:"optional,omitempty"`
}

func (p *Parameter) Copy() *Parameter {
	param := &Parameter{
		Name:     p.Name,
		Types:    make([]string, 0),
		Optional: p.Optional,
	}

	for _, t := range p.Types {
		param.Types = append(param.Types, t)
	}

	return param
}

type ModuleValue struct {
	// Using array because the same values can accept several types.
	// Event though there's only one in most cases.
	Types       []string `json:"types,omitempty"`
	Description string   `json:"description,omitempty"`
}

func (v *ModuleValue) Copy() *ModuleValue {
	value := &ModuleValue{
		Types:       make([]string, 0),
		Description: v.Description,
	}

	for _, t := range v.Types {
		value.Types = append(value.Types, t)
	}

	return value
}

type ModuleProperty struct {
	Name string `json:"name,omitempty"`
	// Using array because the same property be of several types.
	// Event though there's only one in most cases.
	Types []string `json:"types,omitempty"`
	// A description for a property can be just a text,
	// but it can also be enriched with medias, code samples, etc.
	Description []*ContentBlock `json:"description,omitempty"`
	ReadOnly    bool            `json:"read-only,omitempty"`
}

func (p *ModuleProperty) Copy() *ModuleProperty {
	property := &ModuleProperty{
		Name:        p.Name,
		Types:       make([]string, 0),
		Description: make([]*ContentBlock, 0),
		ReadOnly:    p.ReadOnly,
	}

	for _, t := range p.Types {
		property.Types = append(property.Types, t)
	}

	for _, block := range p.Description {
		property.Description = append(property.Description, block) // need copy?
	}

	return property
}

// Returns best possible title for page
func (m *Module) GetTitle() string {
	if m.Name != "" {
		return m.Name
	}
	if m.Types == nil && len(m.Types) > 0 {
		return m.Types[0].Name
	}
	return "Module"
}

func (m *Module) Sanitize() {

	// currentType = m.Type

	// reInlineCode := regexp.MustCompile("`([^`]+)`")
	// inlineCodeReplacement := `<span class="code">$1</span>`
	// inlineCodeReplacementMetaDescription := `$1`

	// reLink := regexp.MustCompile(`\[([^\]]+)\]\(([^)]+)\)`)
	// linkReplacement := `<a href="$2">$1</a>`
	// linkReplacementMetaDescription := `$1`

	// reTypeLink := regexp.MustCompile(`\[([A-Za-z0-9]+)\]`)
	// typeLinkReplacementMetaDescription := `$1`

	// if m.Description != "" {
	// 	// p.Description = strings.TrimSpace(p.Description)
	// 	// p.MetaDescription = p.Description
	// 	// p.Description = strings.ReplaceAll(p.Description, "\n", "<br>")
	// 	// p.Description = reInlineCode.ReplaceAllString(p.Description, inlineCodeReplacement)
	// 	// p.Description = reLink.ReplaceAllString(p.Description, linkReplacement)
	// 	// p.Description = reTypeLink.ReplaceAllStringFunc(p.Description, getTypeLink)

	// 	// p.MetaDescription = strings.ReplaceAll(p.MetaDescription, "\n", " ")
	// 	// p.MetaDescription = reInlineCode.ReplaceAllString(p.MetaDescription, inlineCodeReplacementMetaDescription)
	// 	// p.MetaDescription = reLink.ReplaceAllString(p.MetaDescription, linkReplacementMetaDescription)
	// 	// p.MetaDescription = reTypeLink.ReplaceAllString(p.MetaDescription, typeLinkReplacementMetaDescription)
	// }

	// if m.Functions != nil {
	// 	for _, f := range m.Functions {
	// 		if f.Description != "" {
	// 			f.Description = strings.TrimSpace(f.Description)
	// 			f.Description = strings.ReplaceAll(f.Description, "\n", "<br>")
	// 			f.Description = reInlineCode.ReplaceAllString(f.Description, inlineCodeReplacement)
	// 			f.Description = reLink.ReplaceAllString(f.Description, linkReplacement)
	// 			f.Description = reTypeLink.ReplaceAllStringFunc(f.Description, getTypeLink)
	// 		}
	// 	}
	// }

	// if m.Properties != nil {
	// 	for _, prop := range m.Properties {
	// 		if prop.Description != "" {
	// 			prop.Description = strings.TrimSpace(prop.Description)
	// 			prop.Description = strings.ReplaceAll(prop.Description, "\n", "<br>")
	// 			prop.Description = reInlineCode.ReplaceAllString(prop.Description, inlineCodeReplacement)
	// 			prop.Description = reLink.ReplaceAllString(prop.Description, linkReplacement)
	// 			prop.Description = reTypeLink.ReplaceAllStringFunc(prop.Description, getTypeLink)
	// 		}
	// 	}
	// }

	// sort.Sort(ModuleFunctionsByName(m.Functions))
	// sort.Sort(ModulePropertiesByName(m.Properties))
}

// sort.Interface implementations

type ModulePropertiesByName []*ModuleProperty

func (a ModulePropertiesByName) Len() int           { return len(a) }
func (a ModulePropertiesByName) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ModulePropertiesByName) Less(i, j int) bool { return a[i].Name < a[j].Name }

type ModuleFunctionsByName []*ModuleFunction

func (a ModuleFunctionsByName) Len() int           { return len(a) }
func (a ModuleFunctionsByName) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a ModuleFunctionsByName) Less(i, j int) bool { return a[i].Name < a[j].Name }
