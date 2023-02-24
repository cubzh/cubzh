package main

import (
	"regexp"
	"sort"
	"strings"

	"github.com/gosimple/slug"
)

// Page describes possible content for one page
// in the documentation.
type Page struct {

	// meta keywords
	Keywords []string `yaml:"keywords,omitempty"`

	// meta description, built from Description
	MetaDescription string `yaml:"-,omitempty"`

	// meta description
	Description string `yaml:"description,omitempty"`

	//
	Title string `yaml:"title,omitempty"`

	// object type being described
	// can be left empty if not an object type page
	Type string `yaml:"type,omitempty"`

	// Type that's being extended (optional)
	Extends string `yaml:"extends,omitempty"`

	// The base page if any
	// not set in YAML, set dynamically when parsing files
	Base *Page `yaml:"-"`

	//
	BasicType bool `yaml:"basic-type,omitempty"`

	// Indicates that instances can be created, even if there's no constructor
	Creatable bool `yaml:"creatable,omitempty"`

	// Blocks are a list of displayable content blocks (text, code sample, image)
	// They are displayed before other attributes (constructors, properties, functions)
	Blocks []*ContentBlock `yaml:"blocks,omitempty"`

	Constructors []*Function `yaml:"constructors,omitempty"`

	Properties []*Property `yaml:"properties,omitempty"`

	// Properties from extended pages
	BaseProperties map[string][]*Property `yaml:"-"`

	BuiltIns []*Property `yaml:"built-ins,omitempty"`

	Functions []*Function `yaml:"functions,omitempty"`

	// Functions from extended pages
	// not set in YAML, set dynamically when parsing files
	BaseFunctions map[string][]*Function `yaml:"-"`

	// not set in YAML, set dynamically when parsing files
	ResourcePath string `yaml:"-"`

	// not set in YAML, set dynamically when parsing files
	ExtentionBaseSet bool `yaml:"-"`
}

type Function struct {
	Name      string      `yaml:"name,omitempty"`
	Arguments []*Argument `yaml:"arguments,omitempty"`
	// Used instead arguments when different argument options are available
	ArgumentSets [][]*Argument `yaml:"argument-sets,omitempty"`
	Description  string        `yaml:"description,omitempty"`
	Samples      []*Sample     `yaml:"samples,omitempty"`
	Return       []*Value      `yaml:"return,omitempty"`
	ComingSoon   bool          `yaml:"coming-soon,omitempty"`
	Hide         bool          `yaml:"hide,omitempty"`
}

func (f *Function) Copy() *Function {

	function := &Function{
		Name:        f.Name,
		Description: f.Description,
		ComingSoon:  f.ComingSoon,
		Hide:        f.Hide,
		Arguments:   make([]*Argument, 0),
		Samples:     make([]*Sample, 0),
		Return:      make([]*Value, 0),
	}

	for _, a := range f.Arguments {
		function.Arguments = append(function.Arguments, a.Copy())
	}

	for _, s := range f.Samples {
		function.Samples = append(function.Samples, s.Copy())
	}

	for _, v := range f.Return {
		function.Return = append(function.Return, v.Copy())
	}

	return function
}

type Argument struct {
	Name     string `yaml:"name,omitempty"`
	Type     string `yaml:"type,omitempty"`
	Optional bool   `yaml:"optional,omitempty"`
}

func (a *Argument) Copy() *Argument {
	argument := &Argument{
		Name:     a.Name,
		Type:     a.Type,
		Optional: a.Optional,
	}
	return argument
}

type Value struct {
	Type        string `yaml:"type,omitempty"`
	Description string `yaml:"description,omitempty"`
}

func (v *Value) Copy() *Value {
	value := &Value{
		Type:        v.Type,
		Description: v.Description,
	}
	return value
}

type Sample struct {
	Code  string `yaml:"code,omitempty"`
	Media string `yaml:"media,omitempty"`
}

func (s *Sample) Copy() *Sample {
	sample := &Sample{
		Code:  s.Code,
		Media: s.Media,
	}
	return sample
}

func SampleHasCodeAndMedia(s *Sample) bool {
	return s.Code != "" && s.Media != ""
}

type Property struct {
	Name string `yaml:"name,omitempty"`
	Type string `yaml:"type,omitempty"`
	// When a property acceps several possible types
	Types       []string  `yaml:"types,omitempty"`
	Description string    `yaml:"description,omitempty"`
	Samples     []*Sample `yaml:"samples,omitempty"`
	ReadOnly    bool      `yaml:"read-only,omitempty"`
	ComingSoon  bool      `yaml:"coming-soon,omitempty"`
	Hide        bool      `yaml:"hide,omitempty"`
}

func (p *Property) Copy() *Property {
	property := &Property{
		Name:        p.Name,
		Type:        p.Type,
		Description: p.Description,
		ReadOnly:    p.ReadOnly,
		ComingSoon:  p.ComingSoon,
		Hide:        p.Hide,
		Samples:     make([]*Sample, 0),
	}

	for _, s := range p.Samples {
		property.Samples = append(property.Samples, s.Copy())
	}

	return property
}

// SetExtensionBase sets base property fields when extension ones are empty
func (p *Property) SetExtensionBase(baseProperty *Property) {

	// Name is how extension overrides are detected
	// it doesn't make sense to apply base on that field

	// Type is always defined for an extension
	// it doesn't make sense to apply base on that field

	if p.Description == "" {
		p.Description = baseProperty.Description
	}

	// ReadOnly can't be changed by extending a type
	// enforce this here.
	p.ReadOnly = baseProperty.ReadOnly

	// extension has to be "coming soon" if base is
	if baseProperty.ComingSoon && p.ComingSoon == false {
		p.ComingSoon = true
	}

	if p.Samples == nil || len(p.Samples) == 0 {
		p.Samples = make([]*Sample, 0)
		for _, s := range baseProperty.Samples {
			p.Samples = append(p.Samples, s.Copy())
		}
	}
}

// Only one attribute can be set, others will
// be ignored if set.
type ContentBlock struct {
	Text string `yaml:"text,omitempty"`
	// Lua code
	Code     string   `yaml:"code,omitempty"`
	List     []string `yaml:"list,omitempty"`
	Title    string   `yaml:"title,omitempty"`
	Subtitle string   `yaml:"subtitle,omitempty"`
	// Can be a relative link to an image (png / jpeg)
	Image string `yaml:"image,omitempty"`
	// Can be a relative link to a movie, a link to a youtube video...
	Media string `yaml:"media,omitempty"`
	// Keys couple:
	//  title: Display name for the audio player
	//  file: Relative link to a sound file (.mp3)
	Audio map[string]string `yaml:"audio,omitempty"`
	// List of key couples:
	//  title: Display name for the audio player
	//  file: Relative link to a sound file (.mp3)
	AudioList []map[string]string `yaml:"audiolist,omitempty"`
}

// Returns best possible title for page
func (p *Page) GetTitle() string {
	if p.Type != "" {
		return p.Type
	}
	return p.Title
}

// IsNotCreatableObject returns true if the page describes an object
// that can't be created, has to be accessed through its global variable.
func (p *Page) IsNotCreatableObject() bool {
	return p.Creatable == false && p.BasicType == false && p.Type != "" && (p.Constructors == nil || len(p.Constructors) == 0)
}

// ReadyToBeSetAsBase ...
func (p *Page) ReadyToBeSetAsBase() bool {
	return p.Extends == "" || p.ExtentionBaseSet == true
}

var currentType = ""

func getTypeLink(str string) string {

	str = strings.TrimSuffix(str, "]")
	str = strings.TrimPrefix(str, "[")

	if str == "This" {
		str = currentType
	}

	if route, ok := typeRoutes[str]; ok {
		str = "<a class=\"type\" href=\"" + route + "\">" + str + "</a>"
	}

	return str
}

// SetExtentionBase imports definition from extension base
func (p *Page) SetExtentionBase(base *Page) {

	// Recursion to consider all bases.
	// The type could be the extension of other extensions.
	if base.Base != nil {
		p.SetExtentionBase(base.Base)
	}

	p.Base = base

	if p.BaseFunctions == nil {
		p.BaseFunctions = make(map[string][]*Function)
	}

	if p.BaseProperties == nil {
		p.BaseProperties = make(map[string][]*Property)
	}

	if base.Functions != nil {

		var overriden bool
		for _, function := range base.Functions {
			overriden = false
			for _, extensionFunction := range p.Functions {
				if extensionFunction.Name == function.Name {
					overriden = true
					break
				}
			}

			if overriden == false {

				if p.BaseFunctions[base.Type] == nil {
					p.BaseFunctions[base.Type] = make([]*Function, 0)
				}
				p.BaseFunctions[base.Type] = append(p.BaseFunctions[base.Type], function.Copy())

			} else { // override with non-empty fields, keep others from base

				// TODO

			}
		}
	}

	if base.Properties != nil {

		var overriden bool
		for _, property := range base.Properties {
			overriden = false
			for _, extensionProperty := range p.Properties {
				if extensionProperty.Name == property.Name {
					overriden = true
					// override with non-empty fields, keep others from base
					extensionProperty.SetExtensionBase(property)
					break
				}
			}

			if overriden == false {
				if p.BaseProperties[base.Type] == nil {
					p.BaseProperties[base.Type] = make([]*Property, 0)
				}

				p.BaseProperties[base.Type] = append(p.BaseProperties[base.Type], property.Copy())
			}
		}
	}
}

func (p *Page) Sanitize() {

	currentType = p.Type

	reInlineCode := regexp.MustCompile("`([^`]+)`")
	inlineCodeReplacement := `<span class="code">$1</span>`
	inlineCodeReplacementMetaDescription := `$1`

	reLink := regexp.MustCompile(`\[([^\]]+)\]\(([^)]+)\)`)
	linkReplacement := `<a href="$2">$1</a>`
	linkReplacementMetaDescription := `$1`

	reTypeLink := regexp.MustCompile(`\[([A-Za-z0-9]+)\]`)
	typeLinkReplacementMetaDescription := `$1`

	if p.Description != "" {
		p.Description = strings.TrimSpace(p.Description)
		p.MetaDescription = p.Description
		p.Description = strings.ReplaceAll(p.Description, "\n", "<br>")
		p.Description = reInlineCode.ReplaceAllString(p.Description, inlineCodeReplacement)
		p.Description = reLink.ReplaceAllString(p.Description, linkReplacement)
		p.Description = reTypeLink.ReplaceAllStringFunc(p.Description, getTypeLink)

		p.MetaDescription = strings.ReplaceAll(p.MetaDescription, "\n", " ")
		p.MetaDescription = reInlineCode.ReplaceAllString(p.MetaDescription, inlineCodeReplacementMetaDescription)
		p.MetaDescription = reLink.ReplaceAllString(p.MetaDescription, linkReplacementMetaDescription)
		p.MetaDescription = reTypeLink.ReplaceAllString(p.MetaDescription, typeLinkReplacementMetaDescription)
	}

	if p.Blocks != nil {
		for _, b := range p.Blocks {
			if b.Text != "" {
				b.Text = strings.TrimSpace(b.Text)
				b.Text = strings.ReplaceAll(b.Text, "\n", "<br>")
				b.Text = reInlineCode.ReplaceAllString(b.Text, inlineCodeReplacement)
				b.Text = reLink.ReplaceAllString(b.Text, linkReplacement)
				b.Text = reTypeLink.ReplaceAllStringFunc(b.Text, getTypeLink)
			}
		}
	}

	if p.Constructors != nil {
		for _, c := range p.Constructors {
			if c.Description != "" {
				c.Description = strings.TrimSpace(c.Description)
				c.Description = strings.ReplaceAll(c.Description, "\n", "<br>")
				c.Description = reInlineCode.ReplaceAllString(c.Description, inlineCodeReplacement)
				c.Description = reLink.ReplaceAllString(c.Description, linkReplacement)
				c.Description = reTypeLink.ReplaceAllStringFunc(c.Description, getTypeLink)
			}
		}
	}

	if p.Functions != nil {
		for _, f := range p.Functions {
			if f.Description != "" {
				f.Description = strings.TrimSpace(f.Description)
				f.Description = strings.ReplaceAll(f.Description, "\n", "<br>")
				f.Description = reInlineCode.ReplaceAllString(f.Description, inlineCodeReplacement)
				f.Description = reLink.ReplaceAllString(f.Description, linkReplacement)
				f.Description = reTypeLink.ReplaceAllStringFunc(f.Description, getTypeLink)
			}
		}
	}

	if p.BaseFunctions != nil {
		for _, functions := range p.BaseFunctions {
			for _, f := range functions {
				if f.Description != "" {
					f.Description = strings.TrimSpace(f.Description)
					f.Description = strings.ReplaceAll(f.Description, "\n", "<br>")
					f.Description = reInlineCode.ReplaceAllString(f.Description, inlineCodeReplacement)
					f.Description = reLink.ReplaceAllString(f.Description, linkReplacement)
					f.Description = reTypeLink.ReplaceAllStringFunc(f.Description, getTypeLink)
				}
			}
		}
	}

	if p.Properties != nil {
		for _, prop := range p.Properties {
			if prop.Description != "" {
				prop.Description = strings.TrimSpace(prop.Description)
				prop.Description = strings.ReplaceAll(prop.Description, "\n", "<br>")
				prop.Description = reInlineCode.ReplaceAllString(prop.Description, inlineCodeReplacement)
				prop.Description = reLink.ReplaceAllString(prop.Description, linkReplacement)
				prop.Description = reTypeLink.ReplaceAllStringFunc(prop.Description, getTypeLink)
			}
		}
	}

	if p.BaseProperties != nil {
		for _, properties := range p.BaseProperties {
			for _, prop := range properties {
				if prop.Description != "" {
					prop.Description = strings.TrimSpace(prop.Description)
					prop.Description = strings.ReplaceAll(prop.Description, "\n", "<br>")
					prop.Description = reInlineCode.ReplaceAllString(prop.Description, inlineCodeReplacement)
					prop.Description = reLink.ReplaceAllString(prop.Description, linkReplacement)
					prop.Description = reTypeLink.ReplaceAllStringFunc(prop.Description, getTypeLink)
				}
			}
		}
	}

	if p.BuiltIns != nil {
		for _, b := range p.BuiltIns {
			if b.Description != "" {
				b.Description = strings.TrimSpace(b.Description)
				b.Description = strings.ReplaceAll(b.Description, "\n", "<br>")
				b.Description = reInlineCode.ReplaceAllString(b.Description, inlineCodeReplacement)
				b.Description = reLink.ReplaceAllString(b.Description, linkReplacement)
				b.Description = reTypeLink.ReplaceAllStringFunc(b.Description, getTypeLink)
			}
		}
	}

	sort.Sort(FunctionsByName(p.Functions))
	sort.Sort(PropertiesByName(p.Properties))
	sort.Sort(PropertiesByName(p.BuiltIns))
}

func GetAnchorLink(s string) string {
	return slug.Make(s)
}

// sort.Interface implementations

type PropertiesByName []*Property

func (a PropertiesByName) Len() int           { return len(a) }
func (a PropertiesByName) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a PropertiesByName) Less(i, j int) bool { return a[i].Name < a[j].Name }

type FunctionsByName []*Function

func (a FunctionsByName) Len() int           { return len(a) }
func (a FunctionsByName) Swap(i, j int)      { a[i], a[j] = a[j], a[i] }
func (a FunctionsByName) Less(i, j int) bool { return a[i].Name < a[j].Name }
